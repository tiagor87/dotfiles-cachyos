#!/usr/bin/env bash
# 11-face-unlock.sh — Reconhecimento facial por infravermelho (Howdy), se houver câmera IR
#
# Detecta a câmera IR pelos nós v4l2 do sysfs (sem depender do v4l-utils). Se existir:
#   - instala o howdy-next (reescrita em C++ do Howdy; o howdy clássico puxa
#     python-dlib, compilação longa e frágil),
#   - baixa os modelos (ONNX), aponta o config.ini para o nó IR,
#   - mede se o emissor IR realmente acende (sem ele o Howdy só vê preto),
#   - ajusta o max_height para a resolução nativa do sensor,
#   - cadastra QUANTOS MODELOS você quiser, em ciclo (um por condição: sem
#     óculos, de óculos, luz diferente), testando cada um na hora,
#   - valida com `howdy test` que o reconhecimento REALMENTE funciona.
# Por default para aí: NÃO toca em nenhum stack de autenticação. O rosto no
# sudo/lock/greeter é opt-in por variável de ambiente (ver passo 8), e só sai do
# lugar se o `howdy test` tiver passado.
# Em máquina sem câmera IR (ex.: desktop), sai sem alterar nada. Idempotente.
#
# ATENÇÃO ao que o rosto NÃO faz: no lock do DMS ele não é hands-free. O DMS só
# inicia o PAM quando você aperta Enter (LockScreenContent.qml → onAccepted →
# pam.passwd.start()), então o fluxo é Enter com o campo vazio e AÍ o rosto roda.
# Quem destrava olhando/tocando de forma contínua é a digital, que o DMS conduz
# por D-Bus, fora do PAM. Ver o desktop/pam/dankshell-face para a ordem do stack.
#
# GREEN (critério de sucesso):
#   - Run default: a validação do passo 7 fica ✓ E
#     `grep -rl pam_howdy /etc/pam.d/` não retorna nada (nada foi tocado).
#   - Mais de um modelo: `sudo howdy -U $USER list` mostra uma linha por modelo,
#     e o reconhecimento funciona nas duas condições (com e sem óculos).
#   - Com DOTFILES_FACE_PAM=1: `sudo -k && sudo true` libera pelo rosto, e a
#     senha continua funcionando quando o rosto falha (ESPERE o prompt aparecer
#     antes de digitar — o workaround=native suprime o prompt enquanto escaneia).
# Se o teste falhar com imagem preta, o emissor IR não está ligado: veja o passo 5.
set -uo pipefail

# Os outros scripts do repo exigem DOTFILES_ROOT do setup.sh (${VAR:?}). Este é
# a exceção deliberada: as flags DOTFILES_FACE_* existem para ele ser chamado
# à mão, fora do pipeline, então deduzimos a raiz do próprio caminho do script
# quando a variável não vem do ambiente. O setup.sh continua mandando a sua.
: "${DOTFILES_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Mesma guarda do setup.sh, repetida aqui porque este script é chamado DIRETO
# (por causa das flags DOTFILES_FACE_*), fora do pipeline. Como root, o $USER
# seria 'root': o `howdy add` cadastraria o rosto do root e o sudo do seu usuário
# continuaria sem reconhecer ninguém — falha silenciosa e confusa de achar.
if [[ ${EUID} -eq 0 ]]; then
    c_err "Não rode como root. Rode como seu usuário — ele usa sudo só onde precisa."
    c_err "Como root, o rosto seria cadastrado para 'root', não para você."
    return 1 2>/dev/null || exit 1
fi

SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
HOWDY_CONF=/etc/howdy/config.ini
LOCK_PAM=/etc/pam.d/dankshell-face
LOCK_PAM_SRC="$DOTFILES_ROOT/desktop/pam/dankshell-face"

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
# webcam RGB e a IR trocarem, o Howdy passa a olhar pela câmera errada. O
# config.ini do próprio Howdy recomenda /dev/v4l/by-path/*. Trocamos pelo link
# estável quando existe (aqui a by-id não serve: ela só cobre os nós da RGB).
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
#     repo_install fazem `sudo -v`, mais os `sudo howdy ...`), então um único run
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
# 2) howdy-next (AUR). O pacote traz o pam_howdy.so e o CLI 'howdy'.
# ---------------------------------------------------------------------------
aur_install howdy-next

if ! command -v howdy >/dev/null 2>&1; then
    c_err "CLI 'howdy' não encontrado após a instalação — parei aqui."
    log_entry face howdy failed "howdy-next não instalou o CLI"
    return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------
# 3) Modelos do reconhecimento (baixados do HuggingFace, download único). São
#    ONNX e vão para /usr/share/howdy/models — que o pacote instala VAZIO.
#    (/etc/howdy/models é outra coisa: os rostos cadastrados, e é root-only.)
# ---------------------------------------------------------------------------
if find /usr/share/howdy/models -name '*.onnx' -print -quit 2>/dev/null | grep -q .; then
    pkg_status "howdy: modelos" "= já baixados" "$C_DIM"
    log_entry face models skipped "*.onnx já em /usr/share/howdy/models"
elif sudo howdy download-models; then
    pkg_status "howdy: modelos" "✓ baixados" "$C_GREEN"
    log_entry face models installed "howdy download-models"
else
    pkg_status "howdy: modelos" "✗ download falhou" "$C_RED"
    log_entry face models failed "howdy download-models"
fi

# ---------------------------------------------------------------------------
# 4) Aponta o Howdy para o nó IR. Só reescreve a chave se ela JÁ existir — não
#    inventamos schema de config.ini (varia entre o Howdy 2.x e o next 3.x).
# ---------------------------------------------------------------------------
#    Cuidado ao reportar: 'sudo test -f' falha tanto quando o arquivo não existe
#    quanto quando o sudo não autentica (ex.: rodado sem TTY). Distinguimos os
#    dois, senão a mensagem manda caçar o problema errado.
#
#    E cuidado DOBRADO com como se testa isso: um `sudo -v` sem TTY conta como
#    TENTATIVA FALHA no pam_faillock, mesmo sem nenhuma senha digitada. Três
#    execuções assim travam a conta por 10 min (medido: 2026-07-31 13:37:11/13/16
#    foram três runs de teste, zero senhas). Então só checamos o cache com
#    `sudo -n` (não autentica, não conta) e exigimos TTY antes de deixar o sudo
#    pedir senha.
if ! sudo -n true 2>/dev/null && [[ ! -t 0 || ! -t 1 ]]; then
    pkg_status "howdy: device_path" "✗ sudo indisponível (rode num terminal real)" "$C_RED"
    log_entry face device-path failed "sem credencial em cache e sem TTY p/ pedir senha"
elif ! sudo test -f "$HOWDY_CONF"; then
    pkg_status "howdy: device_path" "✗ $HOWDY_CONF ausente" "$C_RED"
    log_entry face device-path failed "$HOWDY_CONF não existe"
elif sudo grep -qE "^[[:space:]]*device_path[[:space:]]*=[[:space:]]*$ir_dev[[:space:]]*$" "$HOWDY_CONF"; then
    pkg_status "howdy: device_path" "= já é $ir_dev" "$C_DIM"
    log_entry face device-path skipped "$ir_dev"
elif sudo grep -qE "^[[:space:]]*device_path[[:space:]]*=" "$HOWDY_CONF"; then
    if sudo sed -i -E "s|^([[:space:]]*device_path[[:space:]]*=[[:space:]]*).*|\1$ir_dev|" "$HOWDY_CONF"; then
        pkg_status "howdy: device_path" "✓ $ir_dev" "$C_GREEN"
        log_entry face device-path configured "device_path=$ir_dev"
    else
        pkg_status "howdy: device_path" "✗ falhou" "$C_RED"
        log_entry face device-path failed "sed em $HOWDY_CONF"
    fi
else
    pkg_status "howdy: device_path" "✗ chave ausente (rode 'sudo howdy config')" "$C_RED"
    log_entry face device-path failed "device_path não está em $HOWDY_CONF"
fi

# 4b) max_height na resolução NATIVA do sensor. O default do Howdy é 320, que
#     reduz a imagem; dar todos os pixels ao detector ajudou aqui com óculos
#     (sensor 640x400 → 400). Lemos do v4l2 em vez de fixar um número, e só
#     aumentamos — se o valor no config já for >= nativo, não mexemos.
if command -v v4l2-ctl >/dev/null 2>&1 && sudo test -f "$HOWDY_CONF"; then
    native_h=$(v4l2-ctl -d "$ir_capture" --list-framesizes=GREY 2>/dev/null \
               | grep -oP 'Size: Discrete \d+x\K\d+' | sort -n | tail -1)
    [[ -z $native_h ]] && native_h=$(v4l2-ctl -d "$ir_capture" --get-fmt-video 2>/dev/null \
               | grep -oP 'Width/Height\s*:\s*[0-9]+/\K[0-9]+')
    cur_h=$(sudo grep -oP '^[[:space:]]*max_height[[:space:]]*=[[:space:]]*\K[0-9]+' "$HOWDY_CONF" | head -1)
    if [[ ! $native_h =~ ^[0-9]+$ || -z $cur_h ]]; then
        pkg_status "howdy: max_height" "= não determinei a altura nativa" "$C_DIM"
        log_entry face max-height skipped "native='$native_h' cur='$cur_h'"
    elif (( cur_h >= native_h )); then
        pkg_status "howdy: max_height" "= já é $cur_h (nativo: $native_h)" "$C_DIM"
        log_entry face max-height skipped "$cur_h >= $native_h"
    elif sudo sed -i -E "s|^([[:space:]]*max_height[[:space:]]*=[[:space:]]*).*|\1$native_h|" "$HOWDY_CONF"; then
        pkg_status "howdy: max_height" "✓ $cur_h → $native_h (nativo)" "$C_GREEN"
        log_entry face max-height configured "max_height=$native_h"
    else
        pkg_status "howdy: max_height" "✗ falhou" "$C_RED"
        log_entry face max-height failed "sed em $HOWDY_CONF"
    fi
fi

# ---------------------------------------------------------------------------
# 5) O emissor IR acende? Em muitos notes ele fica desligado e o Howdy só vê
#    preto — daí NÃO adianta cadastrar rosto. Medimos em vez de supor: captura
#    15 quadros e olha a média do mais claro. Escuro é ~0/255, iluminado passa
#    de 30, então 8 é um corte folgado.
#
#    Muita câmera IR INTERCALA quadros iluminados e escuros (o emissor pisca):
#    no Zenbook S 14 os pares dão média ~40 e os ímpares ~0. É normal — o Howdy
#    descarta os escuros pelo 'dark_threshold'. Por isso olhamos o MAIS CLARO.
#
#    Quando o emissor não acende, o conserto é o linux-enable-ir-emitter, mas
#    não o instalamos: a 6.1.2 não compila com opencv 5 (o meson dela pede
#    opencv4 e o Arch/CachyOS só provê opencv5.pc). Só apontamos o caminho.
# ---------------------------------------------------------------------------
repo_install v4l-utils

if ! command -v v4l2-ctl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    pkg_status "emissor IR" "= sem v4l2-ctl/python3 (pulando o teste)" "$C_DIM"
    log_entry face ir-emitter skipped "faltou v4l2-ctl ou python3"
else
    c_info "Testando o emissor IR — a luzinha da câmera vai piscar por uns segundos."
    frames=$(mktemp)
    if timeout 30 v4l2-ctl -d "$ir_dev" --set-fmt-video=pixelformat=GREY \
            --stream-mmap --stream-count=15 --stream-to="$frames" >/dev/null 2>&1 \
       && [[ -s $frames ]]; then
        bright=$(python3 -c '
import sys
d = open(sys.argv[1], "rb").read()
fs = len(d) // 15                       # 15 quadros GREY do mesmo tamanho
print(int(max(sum(d[i*fs:(i+1)*fs]) / fs for i in range(15))) if fs else 0)
' "$frames")
        if [[ $bright =~ ^[0-9]+$ ]] && (( bright >= 8 )); then
            pkg_status "emissor IR" "✓ acende (quadro mais claro: média $bright/255)" "$C_GREEN"
            log_entry face ir-emitter configured "quadro mais claro: média $bright/255"
            # NÃO sugerir mexer no dark_threshold aqui. A chave não é "média
            # mínima": o config.ini diz "skip frames whose darkest histogram bin
            # exceeds this %", default 75. Medido nesta câmera: quadros
            # iluminados ficam em 0–46% no bin mais escuro e os do strobe em
            # 91–100% — ou seja, o default já separa os dois corretamente.
            # Se algum dia precisar afrouxar, o movimento é AUMENTAR, não baixar.
        else
            pkg_status "emissor IR" "✗ só quadros escuros (média ${bright:-?}/255)" "$C_RED"
            log_entry face ir-emitter failed "emissor apagado — média ${bright:-?}/255"
            c_warn "O Howdy não vai enxergar nada assim. Ligue o emissor com o linux-enable-ir-emitter"
            c_warn "(atenção: a 6.1.2 não compila com opencv 5 — o meson dela exige opencv4)."
        fi
    else
        pkg_status "emissor IR" "= não consegui capturar (pulando o teste)" "$C_DIM"
        log_entry face ir-emitter skipped "v4l2-ctl não capturou de $ir_dev (câmera em uso?)"
    fi
    rm -f "$frames"
fi

# ---------------------------------------------------------------------------
# 6) Cadastro + validação, EM CICLO. Um modelo por condição.
#
#    O Howdy compara contra TODOS os modelos do usuário, então cadastrar mais de
#    um é ganho puro — não afrouxa limiar nenhum. Aprendido na prática
#    (2026-07-31): com um único modelo o reconhecimento DE ÓCULOS ficou ruim; um
#    segundo modelo usando óculos resolveu sem tocar no yunet_score_threshold
#    nem no sface_threshold, que continuam nos defaults.
#
#    Cada modelo é validado na hora com `howdy test` (feedback curto: cadastrou,
#    testou, viu o resultado) e no fim rodamos a validação que serve de portão
#    para o passo 8. Sem validação verde, nada de PAM.
# ---------------------------------------------------------------------------
count_models() {
    sudo howdy -U "$USER" --plain list 2>/dev/null | grep -cE '^[[:space:]]*[0-9]+'
}

# test_face <rótulo> → 0 se reconheceu. O timeout é rede de segurança: o
# `timeout` do config.ini já limita o scan, mas se a câmera travar não queremos
# pendurar o setup.
test_face() {
    local label="$1"
    if timeout 30 sudo howdy -U "$USER" test >/dev/null 2>&1; then
        pkg_status "$label" "✓ reconheceu" "$C_GREEN"
        return 0
    fi
    pkg_status "$label" "✗ não reconheceu" "$C_RED"
    return 1
}

models=$(count_models)
if [[ -z $models ]]; then models=0; fi

if [[ ! -t 0 || ! -t 1 ]]; then
    pkg_status "rosto: cadastro" "= pulado (sem TTY)" "$C_DIM"
    log_entry face enroll skipped "sem TTY — rode 'sudo howdy -U $USER add'"
else
    c_info "Cadastre um modelo POR CONDIÇÃO: um sem óculos, um de óculos, e"
    c_info "outro se você usa a máquina com iluminação bem diferente."
    [[ $models -gt 0 ]] && c_info "Já existem $models modelo(s) cadastrado(s)."

    while true; do
        if [[ $models -eq 0 ]]; then
            printf 'Cadastrar um modelo de rosto agora? [S/n]: '
            read -r ans
            [[ $ans =~ ^[nN]$ ]] && break
        else
            printf 'Cadastrar OUTRO modelo (ex.: de óculos)? [s/N]: '
            read -r ans
            [[ $ans =~ ^[sSyY]$ ]] || break
        fi

        c_info "Olhe para a câmera, rosto iluminado, na condição que quer cadastrar."
        if sudo howdy -U "$USER" add; then
            models=$(count_models)
            pkg_status "rosto: cadastro" "✓ modelo #$((models-1)) (total: $models)" "$C_GREEN"
            log_entry face enroll configured "modelo $models via howdy add"
            # Valida ESTE modelo na hora, na mesma condição em que foi cadastrado.
            test_face "rosto: teste do modelo #$((models-1))" \
                || c_warn "Recadastre nessa condição, ou tente inclinar levemente a cabeça."
        else
            pkg_status "rosto: cadastro" "✗ falhou" "$C_RED"
            log_entry face enroll failed "howdy add (emissor IR? câmera em uso?)"
            break
        fi
    done
fi

# ---------------------------------------------------------------------------
# 7) VALIDAÇÃO — o portão para o passo 8.
#
#    Aprendido do jeito difícil (2026-07-31): uma versão anterior escrevia o
#    pam_howdy no /etc/pam.d/sudo e no greetd apenas perguntando "quer?", sem
#    nunca provar que o Howdy reconhecia — e sem NENHUM modelo cadastrado. O
#    pam_howdy com workaround=native SUPRIME o prompt de senha enquanto escaneia
#    (timeout do config.ini, default 4s); quem digita nesse intervalo tem os
#    primeiros caracteres engolidos → senha errada. Três dessas e o pam_faillock
#    (defaults deny=3, unlock_time=600) TRAVA A CONTA — e aí toda autenticação
#    que passa por system-auth recusa até a senha correta, no sudo, no polkit e
#    no lock. Emissor IR aceso (passo 5) NÃO prova reconhecimento: é o
#    `howdy test` que prova.
# ---------------------------------------------------------------------------
face_ok=0
models=$(count_models)
if [[ ${models:-0} -eq 0 ]]; then
    pkg_status "validação (howdy test)" "= sem modelo cadastrado" "$C_DIM"
    log_entry face verify skipped "nenhum modelo cadastrado"
elif test_face "validação (howdy test)"; then
    face_ok=1
    log_entry face verify configured "howdy test ok com $models modelo(s)"
else
    log_entry face verify failed "howdy test falhou — PAM não será tocado"
    c_warn "Sem reconhecimento comprovado eu NÃO mexo em PAM nenhum."
    c_warn "Para diagnosticar qual etapa falha, ligue os avisos e reteste:"
    c_warn "  sudo sed -i 's/^detection_notice.*/detection_notice = true/;" \
            "s/^end_report.*/end_report = true/' $HOWDY_CONF"
    c_warn "  sudo howdy -U $USER snapshot   # veja o que a câmera IR enxerga"
    c_warn "'não detectou' → baixe yunet_score_threshold; 'não reconheceu' →"
    c_warn "cadastre outro modelo NESSA condição (preferível a baixar sface_threshold)."
fi

# ---------------------------------------------------------------------------
# 8) Integração no PAM — OPT-IN EXPLÍCITO, nunca por prompt.
#
#    Escrever em stack de autenticação é o passo que pode te deixar de fora da
#    máquina, então ele exige as DUAS coisas: reconhecimento provado no passo 7
#    e a variável DOTFILES_FACE_PAM=1. O greeter (login!) tem flag própria.
#
#      DOTFILES_FACE_PAM=1     → rosto no sudo (a integração que tem ganho real)
#      DOTFILES_FACE_LOCK=1    → TAMBÉM instala o stack do lock (dankshell-face)
#      DOTFILES_FACE_GREETER=1 → TAMBÉM no greetd (login). Cuidado.
#
#    Uma flag por superfície, e não um pacote só: quem quer rosto no sudo não
#    necessariamente quer no lock (onde não é hands-free) ou no login.
#
#    Todo arquivo tocado ganha .bak-dotfiles-face antes da edição.
# ---------------------------------------------------------------------------
MODULE=$(find /usr/lib -name 'pam_howdy.so' 2>/dev/null | head -1)

# insert_howdy_pam <arquivo-pam> <label> <chave-de-log>
# Insere o bloco marcado do Howdy, com backup antes e rollback se o arquivo sair
# malformado. Ancora DEPOIS da digital quando ela existe (fator mais forte e mais
# rápido primeiro); senão no topo do stack.
insert_howdy_pam() {
    local pam="$1" label="$2" key="$3" anchor tmp bak
    if sudo grep -q 'pam_howdy\.so' "$pam" 2>/dev/null; then
        pkg_status "$label" "= já presente" "$C_DIM"
        log_entry face "$key" skipped "pam_howdy já em $pam"
        return
    fi
    if sudo grep -q '^# <<< dotfiles fprintd' "$pam" 2>/dev/null; then
        anchor='^# <<< dotfiles fprintd'
    elif sudo grep -q '^# END DMS GREETER AUTH' "$pam" 2>/dev/null; then
        anchor='^# END DMS GREETER AUTH'
    elif sudo grep -q '^#%PAM-1.0' "$pam" 2>/dev/null; then
        anchor='^#%PAM-1.0'
    else
        pkg_status "$label" "✗ sem âncora conhecida em $pam" "$C_RED"
        log_entry face "$key" failed "nem #%PAM-1.0 nem blocos conhecidos em $pam"
        return
    fi

    bak="$pam.bak-dotfiles-face"
    sudo cp -a "$pam" "$bak" || {
        pkg_status "$label" "✗ não consegui fazer backup (abortei)" "$C_RED"
        log_entry face "$key" failed "backup de $pam falhou"
        return
    }

    tmp=$(mktemp)
    sudo cat "$pam" | awk -v a="$anchor" '
        { print }
        $0 ~ a && !ins {
            print "# >>> dotfiles howdy — rosto antes da senha (fallback automático)"
            print "auth       sufficient pam_howdy.so workaround=native"
            print "# <<< dotfiles howdy"
            ins = 1
        }
        END { if (!ins) exit 3 }
    ' >"$tmp"
    if [[ $? -ne 0 || ! -s $tmp ]]; then
        pkg_status "$label" "✗ falhou ao gerar (arquivo inalterado)" "$C_RED"
        log_entry face "$key" failed "awk não achou a âncora em $pam"
        rm -f "$tmp"; return
    fi

    # Sanidade mínima antes de instalar: o bloco entrou e o stack não encurtou.
    if [[ $(grep -c . "$tmp") -lt $(sudo grep -c . "$pam") ]] \
       || ! grep -q 'pam_howdy\.so' "$tmp"; then
        pkg_status "$label" "✗ resultado suspeito (descartado)" "$C_RED"
        log_entry face "$key" failed "saída do awk não passou na sanidade"
        rm -f "$tmp"; return
    fi

    if sudo cp "$tmp" "$pam"; then
        pkg_status "$label" "✓ habilitado (backup: $bak)" "$C_GREEN"
        log_entry face "$key" configured "pam_howdy sufficient em $pam"
        # Rollback na tela, não escondido num comentário: se a autenticação
        # quebrar, você já vai estar sem sudo para descobrir o comando.
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

if [[ ${DOTFILES_FACE_PAM:-0} != 1 ]]; then
    pkg_status "rosto no PAM" "= opt-in (DOTFILES_FACE_PAM=1)" "$C_DIM"
    log_entry face pam skipped "DOTFILES_FACE_PAM != 1"
    c_info "Rosto no PAM é opt-in. Com o 'howdy test' passando, rode:"
    c_info "  DOTFILES_FACE_PAM=1 bash $DOTFILES_ROOT/desktop/install/11-face-unlock.sh"
elif [[ $face_ok -ne 1 ]]; then
    pkg_status "rosto no PAM" "= bloqueado (howdy test não passou)" "$C_DIM"
    log_entry face pam skipped "howdy test não passou — PAM intocado"
elif [[ -z $MODULE ]]; then
    c_warn "pam_howdy.so não encontrado — pulei a integração no PAM."
    log_entry face pam skipped "pam_howdy.so ausente"
else
    c_warn "Vou editar stacks de autenticação. Se algo der errado: o pam_faillock"
    c_warn "trava a conta em 3 falhas (10 min). Caminhos limpos de recuperação:"
    c_warn "  pkexec (polkit-1), 'su', e TTY via Ctrl+Alt+F2 (login) — não os toco."
    c_warn "Ao testar o sudo, ESPERE o prompt aparecer antes de digitar."

    # 8a) Stack do lock do DMS — flag própria. Arquivo separado: o
    #     /etc/pam.d/dankshell é gerado pelo `dms auth sync` e sobrescreveria
    #     qualquer linha nossa.
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

    # 8b) sudo. Howdy ANTES do system-auth: é o que o man 8 pam_howdy prescreve
    #     para serviços que chamam o PAM antes de coletar a senha. Depois não
    #     funciona — o system-auth do Arch termina em [default=die] no authfail,
    #     então senha errada mata o stack antes de chegar aqui.
    insert_howdy_pam /etc/pam.d/sudo "sudo: rosto (PAM)" sudo-pam

    # 8c) greeter (login) — flag separada, porque errar aqui custa o login.
    if [[ ${DOTFILES_FACE_GREETER:-0} == 1 ]]; then
        insert_howdy_pam /etc/pam.d/greetd "greeter: rosto (PAM)" greeter-pam
    else
        pkg_status "greeter: rosto (PAM)" "= opt-in (DOTFILES_FACE_GREETER=1)" "$C_DIM"
        log_entry face greeter-pam skipped "DOTFILES_FACE_GREETER != 1"
    fi
fi
