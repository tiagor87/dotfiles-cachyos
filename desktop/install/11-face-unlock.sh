#!/usr/bin/env bash
# 11-face-unlock.sh — Reconhecimento facial por infravermelho (Gaze), se houver câmera IR
#
# Gaze: https://github.com/GunduLabs/gaze (substitui o Howdy). Detecta a câmera IR
# pelos nós v4l2 do sysfs (sem depender do v4l-utils). Se existir:
#   - migra do Howdy: tira os blocos "dotfiles howdy" do PAM ANTES de qualquer
#     outra coisa (um pam_howdy.so órfão num stack é bagunça na autenticação),
#   - instala o gaze-bin (AUR; traz o daemon gazed, o CLI e o pam_gaze.so) e liga
#     o gazed. O pós-install do pacote já põe o rosto no sudo e no polkit-1,
#   - aponta o Gaze para o nó IR (rgb = "" → só IR, como o Howdy fazia),
#   - mede se o emissor IR realmente acende (sem ele o Gaze só vê preto),
#   - cadastra rostos em ciclo (um por condição: sem óculos, de óculos, luz
#     diferente), testando cada um na hora,
#   - valida com `gaze auth` que o reconhecimento REALMENTE funciona.
# Por default para aí: NÃO toca no greeter nem no lock. O rosto no login/lock é
# opt-in por variável de ambiente (ver passo 7), e só sai do lugar se o
# `gaze auth` tiver passado.
# Em máquina sem câmera IR (ex.: desktop), sai sem alterar nada. Idempotente.
#
# ATENÇÃO ao que o rosto NÃO faz: no lock do DMS ele não é hands-free. O DMS só
# inicia o PAM quando você aperta Enter (LockScreenContent.qml → onAccepted →
# pam.passwd.start()), então o fluxo é Enter com o campo vazio e AÍ o rosto roda.
# Quem destrava olhando/tocando de forma contínua é a digital, que o DMS conduz
# por D-Bus, fora do PAM. Mesma coisa no greeter. Ver o desktop/pam/dankshell-face.
#
# GREEN (critério de sucesso):
#   - Run default: `gaze auth` fica ✓ E `grep -l pam_howdy /etc/pam.d/*` não
#     retorna nada E `grep -c pam_gaze /etc/pam.d/sudo` ≥ 1 (pós-install do pacote).
#   - Com DOTFILES_FACE_LOCK=1 / DOTFILES_FACE_GREETER=1: o lock e o greetd
#     passam a ter pam_gaze, e `gaze doctor` não reclama do PAM.
#   - `sudo -k && sudo true` libera pelo rosto, e a senha continua funcionando
#     quando o rosto falha.
# Se o teste falhar com imagem preta, o emissor IR não está ligado: veja o passo 4.
set -uo pipefail

# Os outros scripts do repo exigem DOTFILES_ROOT do setup.sh (${VAR:?}). Este é
# a exceção deliberada: as flags DOTFILES_FACE_* existem para ele ser chamado
# à mão, fora do pipeline, então deduzimos a raiz do próprio caminho do script
# quando a variável não vem do ambiente. O setup.sh continua mandando a sua.
: "${DOTFILES_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Mesma guarda do setup.sh, repetida aqui porque este script é chamado DIRETO
# (por causa das flags DOTFILES_FACE_*), fora do pipeline. Como root, o $USER
# seria 'root': o `gaze add-face` cadastraria o rosto do root e o sudo do seu
# usuário continuaria sem reconhecer ninguém — falha silenciosa e confusa de achar.
if [[ ${EUID} -eq 0 ]]; then
    c_err "Não rode como root. Rode como seu usuário — ele usa sudo só onde precisa."
    c_err "Como root, o rosto seria cadastrado para 'root', não para você."
    return 1 2>/dev/null || exit 1
fi

GAZE_CONF=/etc/gaze/config.toml
LOCK_PAM=/etc/pam.d/dankshell-face
LOCK_PAM_SRC="$DOTFILES_ROOT/desktop/pam/dankshell-face"
BAK_SUFFIX=.bak-dotfiles-gaze

# ---------------------------------------------------------------------------
# 1) Há câmera IR? O sysfs expõe o nome de cada nó v4l2 sem precisar do
#    v4l-utils. Nós com index != 0 são metadata (uvcvideo) — só o index 0
#    captura vídeo. Heurística: nome com "IR"/"infrared" (ex.: "ASUS IR camera").
# ---------------------------------------------------------------------------
ir_dev="" ir_name=""
for node in /sys/class/video4linux/video*; do
    [[ -r $node/name && -r $node/index ]] || continue
    [[ $(<"$node/index") == 0 ]] || continue
    name=$(<"$node/name")
    [[ $name =~ (^|[^[:alnum:]])([Ii][Rr]|[Ii]nfra[Rr]ed)([^[:alnum:]]|$) ]] || continue
    ir_dev="/dev/${node##*/}"; ir_name="$name"
    break
done

# Plano B: câmera IR sem "IR" no nome. Um sensor IR só entrega greyscale — se o
# nó tem GREY como ÚNICO formato, não é a webcam RGB. Só roda se houver v4l2-ctl.
if [[ -z $ir_dev ]] && command -v v4l2-ctl >/dev/null 2>&1; then
    for node in /sys/class/video4linux/video*; do
        [[ -r $node/index ]] || continue
        [[ $(<"$node/index") == 0 ]] || continue
        dev="/dev/${node##*/}"
        fmts=$(v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -c "^[[:space:]]*\[")
        [[ $fmts == 1 ]] || continue
        v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -q "'GREY'" || continue
        ir_dev="$dev"; ir_name="$(<"$node/name") (só GREY)"
        break
    done
fi

if [[ -z $ir_dev ]]; then
    pkg_status "câmera infravermelha" "= nenhuma detectada (pulando)" "$C_DIM"
    log_entry face camera skipped "nenhum nó v4l2 com cara de IR"
    c_info "Sem câmera IR. Se o note tem uma, confira 'ls /sys/class/video4linux/*/name'."
    return 0 2>/dev/null || exit 0
fi
pkg_status "câmera infravermelha" "✓ $ir_dev ($ir_name)" "$C_GREEN"
log_entry face camera configured "$ir_dev — $ir_name"

# O número em /dev/videoN NÃO é estável entre boots/re-enumeração do USB — se a
# webcam RGB e a IR trocarem, o teste do emissor olharia a câmera errada. Para
# os testes de v4l2 usamos o link estável /dev/v4l/by-path/* quando existe (a
# by-id não serve: ela só cobre os nós da RGB). O Gaze, esse, é apontado pelo
# USB VID:PID no passo 3 (ver lá).
ir_capture="$ir_dev"
for link in /dev/v4l/by-path/*-video-index0; do
    [[ -e $link ]] || continue
    [[ $(readlink -f "$link") == "$ir_dev" ]] || continue
    ir_dev="$link"
    pkg_status "câmera: caminho estável" "✓ ${link##*/}" "$C_GREEN"
    log_entry face camera-path configured "$link → $ir_capture"
    break
done
if [[ $ir_dev == "$ir_capture" ]]; then
    pkg_status "câmera: caminho estável" "= sem by-path (usando $ir_dev)" "$C_DIM"
    log_entry face camera-path skipped "nenhum by-path resolve p/ $ir_capture"
fi

# ---------------------------------------------------------------------------
# 1b) PRÉ-VOO DE SUDO — antes da primeira chamada de sudo, e depois da detecção
#     (máquina sem câmera IR sai no passo 1 sem nunca precisar de sudo).
#
#     Por que isto existe: cada invocação de sudo que chega ao PAM sem conseguir
#     autenticar grava uma TENTATIVA FALHA no pam_faillock, mesmo sem NENHUMA
#     senha digitada. Este script chama sudo várias vezes (aur_install e
#     repo_install fazem `sudo -v`, mais os `sudo systemctl ...`), então um único run
#     sem TTY soma 3 falhas e TRAVA A CONTA por 10 min (deny=3). Medido em
#     2026-07-31: um run sem TTY = exatamente 3 falhas, zero senhas.
#
#     `sudo -n` só consulta o cache: não autentica, não conta falha.
# ---------------------------------------------------------------------------
if ! sudo -n true 2>/dev/null && [[ ! -t 0 || ! -t 1 ]]; then
    c_err "Sem credencial de sudo em cache e sem TTY para pedir a senha."
    c_err "Rode num terminal real. Se eu seguisse, cada chamada de sudo gravaria"
    c_err "uma falha no pam_faillock e 3 delas travariam sua conta por 10 min."
    log_entry face sudo-preflight failed "sem cache de sudo e sem TTY — abortei antes de tocar no PAM"
    return 1 2>/dev/null || exit 1
fi


# ---------------------------------------------------------------------------
# 2) Migração do Howdy + instalação do Gaze.
#
#    2a) Tira os blocos "dotfiles howdy" do PAM antes de tudo. Se o Howdy for
#        desinstalado com a linha ainda lá, o pam_howdy.so some do stack e todo
#        login passa a logar erro de módulo. O .bak-dotfiles-face do passo
#        antigo (se existir) é o arquivo ORIGINAL de antes do Howdy — não é
#        tocado; o backup desta migração tem sufixo próprio.
# ---------------------------------------------------------------------------
strip_howdy_pam() {
    local pam="$1" bak="$1$BAK_SUFFIX"
    sudo grep -q 'pam_howdy\.so' "$pam" 2>/dev/null || return 0
    sudo cp -an "$pam" "$bak" || {
        pkg_status "howdy: sai do $pam" "✗ backup falhou (abortei)" "$C_RED"
        log_entry face howdy-strip failed "backup de $pam falhou"
        return 1
    }
    sudo sed -i '/^# >>> dotfiles howdy/,/^# <<< dotfiles howdy/d' "$pam"
    if sudo grep -q 'pam_howdy\.so' "$pam"; then
        # Linha fora do bloco marcado: não adivinho, devolvo o original.
        sudo cp -a "$bak" "$pam"
        pkg_status "howdy: sai do $pam" "✗ pam_howdy fora do bloco marcado (restaurei)" "$C_RED"
        log_entry face howdy-strip failed "pam_howdy em $pam fora do bloco dotfiles — edite à mão"
        return 1
    fi
    pkg_status "howdy: sai do $pam" "✓ removido (backup: $bak)" "$C_GREEN"
    log_entry face howdy-strip configured "bloco howdy removido de $pam"
}
for pam in /etc/pam.d/sudo /etc/pam.d/greetd /etc/pam.d/dankshell-face; do
    strip_howdy_pam "$pam" || exit 1
done

# 2b) Gaze. O pós-install do AUR faz sozinho: gazed habilitado, rosto no sudo
#     (com faillock preauth antes) e override do polkit-1.
aur_install gaze-bin

if ! command -v gaze >/dev/null 2>&1; then
    c_err "CLI 'gaze' não encontrado após a instalação — parei aqui."
    log_entry face gaze failed "gaze-bin não instalou o CLI"
    return 0 2>/dev/null || exit 0
fi

if systemctl is-active --quiet gazed; then
    pkg_status "gaze: daemon" "= gazed ativo" "$C_DIM"
    log_entry face gazed skipped "gazed já ativo"
elif sudo systemctl enable --now gazed; then
    pkg_status "gaze: daemon" "✓ gazed habilitado e iniciado" "$C_GREEN"
    log_entry face gazed configured "systemctl enable --now gazed"
else
    pkg_status "gaze: daemon" "✗ gazed não subiu (journalctl -u gazed)" "$C_RED"
    log_entry face gazed failed "enable --now gazed"
fi

# ---------------------------------------------------------------------------
# 3) Aponta o Gaze para o nó IR e desliga o RGB.
#
#    rgb = "" → só IR, que é o que o Howdy fazia e o que o Gaze recomenda quando
#    a webcam não aguenta RGB+IR juntos. O IR vai por USB VID:PID, não por
#    /dev/videoN: o número muda entre boots e o `usb:` resolve sempre pro nó
#    mono/IR da vez. Se o `gaze auth` não achar a câmera, o plano B é
#    `ir = "$ir_capture"` (nó fixo) no $GAZE_CONF.
#
#    Só mexe nas chaves do [cameras]; nada além disso. Backup único do original.
# ---------------------------------------------------------------------------
ir_usb=$(udevadm info -q property -n "$ir_capture" 2>/dev/null | awk -F= '
    /^ID_VENDOR_ID=/ {v=$2} /^ID_MODEL_ID=/ {m=$2}
    END { if (v && m) print "usb:" v ":" m }')

# set_toml_key <arquivo> <seção> <chave> <valor-toml> — troca a linha da chave
# (ativa ou comentada) dentro da seção; se não existir, acrescenta no fim dela.
set_toml_key() {
    local file="$1" sec="$2" key="$3" val="$4" tmp
    tmp=$(mktemp)
    sudo awk -v sec="[$sec]" -v key="$key" -v val="$val" '
        function flush() { if (insec && !done) { print key " = " val; done = 1 } }
        /^\[/ { flush(); insec = ($0 == sec) }
        insec && !done && $0 ~ "^#?[[:space:]]*" key "[[:space:]]*=" { print key " = " val; done = 1; next }
        { print }
        END { flush(); if (!done) exit 3 }
    ' "$file" >"$tmp"
    local rc=$?
    if [[ $rc -ne 0 || ! -s $tmp ]]; then rm -f "$tmp"; return 1; fi
    sudo install -m 644 "$tmp" "$file"; rc=$?
    rm -f "$tmp"; return $rc
}

if [[ -z $ir_usb ]]; then
    pkg_status "gaze: câmera" "✗ sem VID:PID do $ir_capture (udevadm)" "$C_RED"
    log_entry face camera-config failed "udevadm sem ID_VENDOR_ID/ID_MODEL_ID"
elif ! sudo test -f "$GAZE_CONF"; then
    pkg_status "gaze: câmera" "✗ $GAZE_CONF ausente" "$C_RED"
    log_entry face camera-config failed "$GAZE_CONF não existe"
elif sudo grep -qE "^ir[[:space:]]*=[[:space:]]*\"$ir_usb\"" "$GAZE_CONF" \
     && sudo grep -qE '^rgb[[:space:]]*=[[:space:]]*""' "$GAZE_CONF"; then
    pkg_status "gaze: câmera" "= já é $ir_usb (só IR)" "$C_DIM"
    log_entry face camera-config skipped "$ir_usb"
else
    sudo cp -an "$GAZE_CONF" "$GAZE_CONF$BAK_SUFFIX"
    if set_toml_key "$GAZE_CONF" cameras rgb '""' \
       && set_toml_key "$GAZE_CONF" cameras ir "\"$ir_usb\""; then
        sudo systemctl restart gazed
        pkg_status "gaze: câmera" "✓ ir=$ir_usb, rgb vazio (só IR)" "$C_GREEN"
        log_entry face camera-config configured "ir=$ir_usb rgb=\"\""
    else
        pkg_status "gaze: câmera" "✗ falhou ao editar $GAZE_CONF" "$C_RED"
        log_entry face camera-config failed "set_toml_key em $GAZE_CONF"
    fi
fi

# ---------------------------------------------------------------------------
# (passo 4) O emissor IR acende? Em muitos notes ele fica desligado e o Gaze só vê
#    preto — daí NÃO adianta cadastrar rosto. Medimos em vez de supor: captura
#    15 quadros e olha a média do mais claro. Escuro é ~0/255, iluminado passa
#    de 30, então 8 é um corte folgado.
#
#    Muita câmera IR INTERCALA quadros iluminados e escuros (o emissor pisca):
#    no Zenbook S 14 os pares dão média ~40 e os ímpares ~0. É normal — o Gaze
#    descarta os escuros sozinho. Por isso olhamos o MAIS CLARO.
#
#    Quando o emissor não acende, o conserto é o linux-enable-ir-emitter, mas
#    não o instalamos: a 6.1.2 não compila com opencv 5 (o meson dela pede
#    opencv4 e o Arch/CachyOS só provê opencv5.pc). Só apontamos o caminho.
# ---------------------------------------------------------------------------
repo_install v4l-utils

# 5a) Antes de medir o emissor: a câmera está bloqueada no hardware? O controle
#     V4L2 `privacy` espelha o bloqueio do EC (a tecla de câmera do teclado —
#     Fn+F10 nos ASUS) e é READ-ONLY: `--set-ctrl privacy=0` responde
#     "Permission denied", não há como destravar por software.
#     O sintoma é traiçoeiro (medido em 2026-08-04, ASUS FHD webcam / ASUS IR
#     camera): bloqueada, a câmera ENTREGA os 15 quadros normalmente, só que
#     preenchidos com um valor CONSTANTE — min=max=144. Média 144 passava
#     folgado no corte de 8 do teste abaixo, então o script dizia "✓ emissor IR
#     acende" para uma câmera cega, e a falha só reaparecia no `gaze auth`, sem
#     pista nenhuma. Sem imagem, threshold nenhum resolve.
if command -v v4l2-ctl >/dev/null 2>&1; then
    privacy=$(timeout 10 v4l2-ctl -d "$ir_dev" --get-ctrl privacy 2>/dev/null \
        | awk -F': ' '/^privacy/{print $2}')
    if [[ ${privacy:-0} == 1 ]]; then
        pkg_status "câmera: bloqueio de hardware" "✗ privacy=1 (câmera desligada)" "$C_RED"
        log_entry face privacy failed "V4L2 privacy=1 — câmera bloqueada pelo EC"
        c_warn "A câmera está DESLIGADA no firmware. Assim ela ENTREGA quadros, mas chapados"
        c_warn "(o sensor RGB devolve literalmente um ícone de câmera riscada), e o IR não acende."
        c_warn "NÃO tem chave de software no Linux para reverter:"
        c_warn "  - o controle 'privacy' do V4L2 é read-only (--set-ctrl responde Permission denied);"
        c_warn "  - o 'Asus WMI hotkeys' só emite KEY_CAMERA (212), não KEY_CAMERA_ACCESS_TOGGLE:"
        c_warn "    o F10 avisa que você apertou, quem desligaria de fato é o driver da ASUS."
        c_warn "Ordem para religar: tecla F10 (ou Fn+F10) → item de câmera no BIOS (F2 no boot)"
        c_warn "→ reabilitar no Windows, se houver dual boot (o EC guarda o estado entre boots)."
        c_warn "Para conferir:  v4l2-ctl -d $ir_dev --get-ctrl privacy   # tem que dar 0"
        c_warn "Paro aqui: sem imagem não há o que cadastrar, e nenhum PAM foi tocado."
        return 0 2>/dev/null || exit 0
    fi
    pkg_status "câmera: bloqueio de hardware" "✓ privacy=${privacy:-ausente}" "$C_GREEN"
fi

if ! command -v v4l2-ctl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    pkg_status "emissor IR" "= sem v4l2-ctl/python3 (pulando o teste)" "$C_DIM"
    log_entry face ir-emitter skipped "faltou v4l2-ctl ou python3"
else
    c_info "Testando o emissor IR — a luzinha da câmera vai piscar por uns segundos."
    frames=$(mktemp)
    if timeout 30 v4l2-ctl -d "$ir_dev" --set-fmt-video=pixelformat=GREY \
            --stream-mmap --stream-count=15 --stream-to="$frames" >/dev/null 2>&1 \
       && [[ -s $frames ]]; then
        # Média E amplitude (max-min) do quadro mais claro. A média sozinha não
        # distingue imagem de preenchimento: quadro chapado tem amplitude 0,
        # imagem IR de verdade passa de 100.
        read -r bright spread < <(python3 -c '
import sys
d = open(sys.argv[1], "rb").read()
fs = len(d) // 15                       # 15 quadros GREY do mesmo tamanho
if not fs:
    print(0, 0)
    raise SystemExit
f = max((d[i*fs:(i+1)*fs] for i in range(15)), key=sum)
print(int(sum(f) / fs), max(f) - min(f))
' "$frames")
        if [[ ! $spread =~ ^[0-9]+$ ]] || (( spread < 8 )); then
            pkg_status "emissor IR" "✗ quadros chapados (amplitude ${spread:-?}, média ${bright:-?}/255)" "$C_RED"
            log_entry face ir-emitter failed "quadros com valor constante — amplitude ${spread:-?}"
            c_warn "A câmera devolve quadros de valor CONSTANTE: não é imagem, é preenchimento."
            c_warn "Quase sempre é bloqueio de hardware (tecla de câmera / Fn+F10) — cheque:"
            c_warn "  v4l2-ctl -d $ir_dev --get-ctrl privacy   # tem que dar 0"
        elif [[ $bright =~ ^[0-9]+$ ]] && (( bright >= 8 )); then
            pkg_status "emissor IR" "✓ acende (quadro mais claro: média $bright/255)" "$C_GREEN"
            log_entry face ir-emitter configured "quadro mais claro: média $bright/255"
        else
            pkg_status "emissor IR" "✗ só quadros escuros (média ${bright:-?}/255)" "$C_RED"
            log_entry face ir-emitter failed "emissor apagado — média ${bright:-?}/255"
            c_warn "O Gaze não vai enxergar nada assim. Ligue o emissor com o linux-enable-ir-emitter"
            c_warn "(atenção: a 6.1.2 não compila com opencv 5 — o meson dela exige opencv4)."
        fi
    else
        pkg_status "emissor IR" "= não consegui capturar (pulando o teste)" "$C_DIM"
        log_entry face ir-emitter skipped "v4l2-ctl não capturou de $ir_dev (câmera em uso?)"
    fi
    rm -f "$frames"
fi


# ---------------------------------------------------------------------------
# 5) Cadastro + validação, EM CICLO. Um rosto por condição.
#
#    O Gaze compara contra os rostos cadastrados do usuário (config.toml,
#    [enrollment] max_templates), então cadastrar um por condição — sem óculos,
#    de óculos — é ganho puro, sem afrouxar limiar. Cada um é validado na hora
#    com `gaze auth` (feedback curto: cadastrou, testou, viu o resultado) e no
#    fim rodamos a validação que serve de portão para o passo 7.
# ---------------------------------------------------------------------------
# test_face <rótulo> → 0 se reconheceu. O timeout é rede de segurança: se a
# câmera travar não queremos pendurar o setup.
#
# --silent, NÃO --verbose: o verbose desenha um TUI (precisa de terminal de
# verdade) e, com a saída redirecionada pro log, morre com "No such device or
# address" / "cursor position could not be read" ANTES de olhar a câmera —
# o teste falhava com o Gaze funcionando. O diagnóstico vem do journal do gazed.
FACE_LOG="${TMPDIR:-/tmp}/dotfiles-gaze-auth.log"
test_face() {
    local label="$1"
    if timeout 30 gaze auth --silent >"$FACE_LOG" 2>&1; then
        pkg_status "$label" "✓ reconheceu" "$C_GREEN"
        return 0
    fi
    pkg_status "$label" "✗ não reconheceu" "$C_RED"
    c_warn "Últimas linhas do gazed (o motivo da recusa — rosto, liveness, câmera):"
    journalctl -u gazed -b --no-pager -n 8 2>/dev/null | cut -c1-220 | sed 's/^/    /'
    c_warn "Diagnóstico completo (câmera, daemon, PAM, TPM):  gaze doctor"
    return 1
}

# Rostos já cadastrados: `gaze list-faces` sai 0 também sem nenhum, então quem
# decide "tem rosto" é o gate abaixo (gaze auth), não esta contagem — ela só
# serve para a mensagem.
if [[ ! -t 0 || ! -t 1 ]]; then
    pkg_status "rosto: cadastro" "= pulado (sem TTY)" "$C_DIM"
    log_entry face enroll skipped "sem TTY — rode 'gaze add-face default'"
else
    c_info "Cadastre um rosto POR CONDIÇÃO: um sem óculos, um de óculos, e"
    c_info "outro se você usa a máquina com iluminação bem diferente."
    c_info "Já cadastrados:"; gaze list-faces 2>&1 | sed 's/^/    /'

    first=1
    while true; do
        if [[ $first -eq 1 ]]; then
            printf 'Cadastrar um rosto agora? [S/n]: '
            read -r ans
            [[ $ans =~ ^[nN]$ ]] && break
            first=0
        else
            printf 'Cadastrar OUTRO rosto (ex.: de óculos)? [s/N]: '
            read -r ans
            [[ $ans =~ ^[sSyY]$ ]] || break
        fi

        printf 'Nome deste cadastro (ex.: default, oculos) [default]: '
        read -r face_name
        face_name=${face_name:-default}
        if [[ ! $face_name =~ ^[[:alnum:]_.-]+$ ]]; then
            c_warn "Nome inválido (use letras, números, _ . -). Tente de novo."
            continue
        fi

        c_info "Olhe para a câmera, rosto iluminado, na condição que quer cadastrar."
        if gaze add-face "$face_name"; then
            pkg_status "rosto: cadastro" "✓ '$face_name'" "$C_GREEN"
            log_entry face enroll configured "gaze add-face $face_name"
            test_face "rosto: teste de '$face_name'" \
                || c_warn "Recadastre nessa condição (gaze refine-face $face_name junta amostras)."
        else
            pkg_status "rosto: cadastro" "✗ falhou" "$C_RED"
            log_entry face enroll failed "gaze add-face $face_name (câmera em uso? gazed ativo?)"
            break
        fi
    done
fi

# ---------------------------------------------------------------------------
# 6) VALIDAÇÃO — o portão para o passo 7.
#
#    Aprendido do jeito difícil (2026-07-31, ainda com o Howdy): uma versão
#    anterior escrevia o módulo de rosto no PAM apenas perguntando "quer?", sem
#    nunca provar que ele reconhecia. Falha de rosto + senha digitada no meio do
#    scan = senha errada; três dessas e o pam_faillock (deny=3, unlock_time=600)
#    TRAVA A CONTA — e aí toda autenticação que passa por system-auth recusa,
#    no sudo, no polkit e no lock. Emissor IR aceso (passo 4) NÃO prova
#    reconhecimento: é o `gaze auth` que prova.
# ---------------------------------------------------------------------------
face_ok=0
if test_face "validação (gaze auth)"; then
    face_ok=1
    log_entry face verify configured "gaze auth ok"
else
    # Uma falha pode ser só a posição/luz do momento. Retestar aqui é bem mais
    # curto que reabrir o script, que refaria os passos 1-5 inteiros.
    while [[ -t 0 && -t 1 ]]; do
        printf 'Testar de novo? [s/N]: '
        read -r ans
        [[ $ans =~ ^[sSyY]$ ]] || break
        test_face "validação (gaze auth)" || continue
        face_ok=1
        log_entry face verify configured "gaze auth ok (após reteste)"
        break
    done
fi

if [[ $face_ok -ne 1 ]]; then
    log_entry face verify failed "gaze auth falhou — greeter/lock não serão tocados ($(tail -n1 "$FACE_LOG" 2>/dev/null))"
    c_warn "Sem reconhecimento comprovado eu NÃO mexo em PAM nenhum além do que o"
    c_warn "pacote já fez no sudo/polkit. Diagnóstico:  gaze doctor"
    c_warn "Se o sudo ficou pedindo rosto sem funcionar, tire a linha dele:"
    c_warn "  sudo sed -i '/pam_gaze/d; /^-auth requisite pam_faillock\\.so preauth\$/d' /etc/pam.d/sudo"
fi

# 6b) Howdy fora, mas só com o Gaze provado: o Howdy é o plano B até aqui.
#     --noconfirm NÃO: apaga também /etc/howdy (os rostos cadastrados), então
#     pergunta.
if [[ $face_ok -eq 1 ]] && pacman -Qq howdy-next >/dev/null 2>&1; then
    if [[ -t 0 && -t 1 ]]; then
        printf 'Gaze funcionando. Desinstalar o howdy-next (apaga /etc/howdy, com os rostos antigos)? [s/N]: '
        read -r ans
        if [[ $ans =~ ^[sSyY]$ ]]; then
            if sudo pacman -Rns howdy-next; then
                pkg_status "howdy-next" "✓ desinstalado" "$C_GREEN"
                log_entry face howdy-remove configured "pacman -Rns howdy-next"
            else
                pkg_status "howdy-next" "✗ pacman -Rns falhou" "$C_RED"
                log_entry face howdy-remove failed "pacman -Rns howdy-next"
            fi
        else
            pkg_status "howdy-next" "= mantido (desinstale: sudo pacman -Rns howdy-next)" "$C_DIM"
            log_entry face howdy-remove skipped "recusado pelo usuário"
        fi
    else
        pkg_status "howdy-next" "= mantido (sem TTY)" "$C_DIM"
        log_entry face howdy-remove skipped "sem TTY"
    fi
fi

# ---------------------------------------------------------------------------
# 7) Integração no PAM do que o pacote NÃO faz — OPT-IN EXPLÍCITO.
#
#    O pós-install do gaze-bin já cuida do sudo e do polkit-1 (e respeita
#    /etc/gaze/pam-sudo.optout). Aqui só o que ele não toca, uma flag por
#    superfície, e exigindo o `gaze auth` verde do passo 6:
#
#      DOTFILES_FACE_LOCK=1    → instala o stack do lock (dankshell-face)
#      DOTFILES_FACE_GREETER=1 → rosto no greetd (login). Cuidado.
#
#    Todo arquivo tocado ganha $BAK_SUFFIX antes da edição.
#
#    Por que o faillock preauth entra antes do pam_gaze: sufficient + sucesso
#    pula o resto do stack, inclusive o pam_faillock. Sem o gate, uma conta
#    TRAVADA ainda autenticaria pelo rosto. (Mesma regra do pós-install.)
# ---------------------------------------------------------------------------
# insert_gaze_pam <arquivo> <label> <chave-de-log> <regex-da-âncora>
# Insere [gate faillock +] pam_gaze ANTES da linha-âncora, com backup e rollback.
insert_gaze_pam() {
    local pam="$1" label="$2" key="$3" anchor="$4" tmp bak="$1$BAK_SUFFIX"
    if sudo grep -q 'pam_gaze\.so' "$pam" 2>/dev/null; then
        pkg_status "$label" "= já presente" "$C_DIM"
        log_entry face "$key" skipped "pam_gaze já em $pam"
        return
    fi
    if ! sudo grep -qE "$anchor" "$pam" 2>/dev/null; then
        pkg_status "$label" "✗ sem âncora ($anchor) em $pam" "$C_RED"
        log_entry face "$key" failed "âncora $anchor ausente em $pam"
        return
    fi
    sudo cp -an "$pam" "$bak" || {
        pkg_status "$label" "✗ não consegui fazer backup (abortei)" "$C_RED"
        log_entry face "$key" failed "backup de $pam falhou"
        return
    }

    tmp=$(mktemp)
    sudo cat "$pam" | awk -v a="$anchor" '
        $0 ~ a && !ins {
            print "# >>> dotfiles gaze — rosto antes da senha (fallback automático)"
            print "-auth      requisite   pam_faillock.so preauth"
            print "auth       sufficient  pam_gaze.so"
            print "# <<< dotfiles gaze"
            ins = 1
        }
        { print }
        END { if (!ins) exit 3 }
    ' >"$tmp"
    if [[ $? -ne 0 || ! -s $tmp ]] || ! grep -q 'pam_gaze\.so' "$tmp" \
       || [[ $(grep -c . "$tmp") -lt $(sudo grep -c . "$pam") ]]; then
        pkg_status "$label" "✗ resultado suspeito (arquivo inalterado)" "$C_RED"
        log_entry face "$key" failed "saída do awk não passou na sanidade em $pam"
        rm -f "$tmp"; return
    fi

    if sudo cp "$tmp" "$pam"; then
        pkg_status "$label" "✓ habilitado (backup: $bak)" "$C_GREEN"
        log_entry face "$key" configured "pam_gaze sufficient em $pam"
        c_info "Se der problema, desfaça com (pkexec funciona sem sudo):"
        c_info "  pkexec cp -a $bak $pam"
        c_info "E se a conta travar por 3 falhas: : > /run/faillock/$USER"
    else
        sudo cp -a "$bak" "$pam"
        pkg_status "$label" "✗ falhou (restaurei do backup)" "$C_RED"
        log_entry face "$key" failed "cp falhou; $pam restaurado de $bak"
    fi
    rm -f "$tmp"
}

# Confere o que o pacote fez no sudo/polkit — não edita, só reporta.
for pam in /etc/pam.d/sudo /etc/pam.d/polkit-1; do
    if sudo grep -q 'pam_gaze\.so' "$pam" 2>/dev/null; then
        pkg_status "rosto: ${pam##*/}" "✓ pam_gaze presente" "$C_GREEN"
    elif [[ -e /etc/gaze/pam-sudo.optout && $pam == */sudo ]]; then
        pkg_status "rosto: ${pam##*/}" "= opt-out (/etc/gaze/pam-sudo.optout)" "$C_DIM"
    else
        pkg_status "rosto: ${pam##*/}" "✗ sem pam_gaze (veja: gaze doctor)" "$C_RED"
        log_entry face "${pam##*/}-pam" failed "pam_gaze ausente em $pam após o pós-install"
    fi
done

if [[ $face_ok -ne 1 ]]; then
    pkg_status "rosto no lock/greeter" "= bloqueado (gaze auth não passou)" "$C_DIM"
    log_entry face pam skipped "gaze auth não passou — lock/greeter intocados"
else
    c_warn "Vou editar stacks de autenticação. Se algo der errado: o pam_faillock"
    c_warn "trava a conta em 3 falhas (10 min). Caminhos limpos de recuperação:"
    c_warn "  pkexec (polkit-1), 'su', e TTY via Ctrl+Alt+F2 (login) — não os toco."

    # 7a) Stack do lock do DMS — arquivo separado: o /etc/pam.d/dankshell é
    #     gerado pelo `dms auth sync` e sobrescreveria qualquer linha nossa.
    if [[ ${DOTFILES_FACE_LOCK:-0} != 1 ]]; then
        pkg_status "lock: PAM do rosto" "= opt-in (DOTFILES_FACE_LOCK=1)" "$C_DIM"
        log_entry face lock-pam skipped "DOTFILES_FACE_LOCK != 1"
    elif sudo install -Dm644 "$LOCK_PAM_SRC" "$LOCK_PAM" 2>/dev/null \
       && dms auth validate --path "$LOCK_PAM" >/dev/null 2>&1; then
        pkg_status "lock: PAM do rosto" "✓ $LOCK_PAM (validado)" "$C_GREEN"
        log_entry face lock-pam configured "$LOCK_PAM validado pelo dms"
        c_info "Para ativar, ponha lockPamPath=\"$LOCK_PAM\" no settings.json versionado."
        c_info "Lembre: no lock o rosto não é hands-free — só roda depois do Enter."
    else
        sudo rm -f "$LOCK_PAM"
        pkg_status "lock: PAM do rosto" "✗ não validou (removido)" "$C_RED"
        log_entry face lock-pam failed "dms auth validate recusou — $LOCK_PAM removido"
    fi

    # 7b) greeter (login) — flag separada, porque errar aqui custa o login.
    #     Âncora: ANTES do `auth include system-local-login`, depois do pam_nologin
    #     (requisite) e do fprintd do DMS: mantém bloqueio de /etc/nologin e a
    #     digital primeiro. O gnome-keyring do greetd fica como está: login por
    #     rosto não entrega senha, então o keyring pede a senha uma vez no
    #     desktop (igual à digital). Destravar via TPM é opcional — ver
    #     https://gaze.gundulabs.com/guide/greetd
    if [[ ${DOTFILES_FACE_GREETER:-0} == 1 ]]; then
        insert_gaze_pam /etc/pam.d/greetd "greeter: rosto (PAM)" greeter-pam \
            '^auth[[:space:]]+include[[:space:]]+system-local-login'
    else
        pkg_status "greeter: rosto (PAM)" "= opt-in (DOTFILES_FACE_GREETER=1)" "$C_DIM"
        log_entry face greeter-pam skipped "DOTFILES_FACE_GREETER != 1"
    fi
fi
