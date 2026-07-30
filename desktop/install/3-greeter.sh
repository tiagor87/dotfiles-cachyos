#!/usr/bin/env bash
# 3-greeter.sh — Login via greeter do DMS (greetd): wallpaper dinâmico,
#                numlock e auto-unlock do keyring.
#
# ⚠️  CRÍTICO DE LOGIN. Instalamos o greetd + o dms-greeter (pacman/yay) e só
# então habilitamos com `dms greeter enable` — isso SUBSTITUI o display manager
# atual (SDDM). Antes de reiniciar, TESTE o login e mantenha um TTY aberto
# (Ctrl+Alt+F3). Para reverter:  dms greeter uninstall
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

if ! command -v dms >/dev/null 2>&1; then
    c_err "binário 'dms' não encontrado — rode o 2-dms.sh primeiro."
    return 0 2>/dev/null || exit 0
fi

# 0) Pacotes: NÓS instalamos os dois (pacman/yay), e deixamos pro dms apenas a
#    configuração (passo 1). O `dms greeter install` também faria a instalação,
#    mas de forma opaca (pacman + build de AUR por dentro, com sudo próprio).
#    - greetd: o daemon. Vem como dependência do greeter, mas pedimos explícito.
#    - greetd-dms-greeter-git: fornece o /usr/bin/dms-greeter referenciado no
#      config do greetd, e NÃO é dependência do dms-shell. Sem ele o boot falha
#      com "/usr/bin/dms-greeter: Arquivo ou diretório inexistente".
repo_install greetd
aur_install greetd-dms-greeter-git

# 1) Habilita o DMS greeter no config do greetd (substitui o SDDM/DM anterior).
#
# ⚠️  CUIDADO COM O GUARD. O /etc/greetd/config.toml JÁ EXISTE assim que o pacote
#     greetd é instalado — com a sessão padrão `agreety` (login em modo texto) —
#     e o `dms greeter status` sai com 0 mesmo com o greeter desabilitado. Usar
#     esses dois como teste de idempotência (era o caso) faz o script PULAR a
#     configuração numa instalação do zero: o greetd sobe no agreety e o login
#     gráfico nunca aparece. O teste real é o config referenciar o dms-greeter.
#     (o config nem sempre é legível pelo usuário — tenta direto, cai pro sudo)
greeter_enabled() {
    grep -q 'dms-greeter' /etc/greetd/config.toml 2>/dev/null \
        || sudo grep -q 'dms-greeter' /etc/greetd/config.toml 2>/dev/null
}

if greeter_enabled; then
    pkg_status "dms greeter" "= já habilitado no greetd" "$C_DIM"
    log_entry greeter enable skipped "config.toml já aponta pro dms-greeter"
else
    c_info "Habilitando o DMS greeter no greetd (vai pedir sudo)..."
    dms greeter enable -y
    if greeter_enabled; then
        pkg_status "dms greeter" "✓ habilitado (greetd)" "$C_GREEN"
        log_entry greeter enable configured "dms greeter enable"
    else
        pkg_status "dms greeter" "✗ falhou" "$C_RED"
        log_entry greeter enable failed "config.toml não aponta pro dms-greeter"
        c_err "greetd continuaria no agreety (login em modo texto) — NÃO reinicie."
        return 0 2>/dev/null || exit 0
    fi
fi

# 1b) Garante que o login GRÁFICO sobe no boot. O `dms greeter install`
#     registra o greetd, mas em instalações enxutas o systemd pode estar em
#     multi-user.target (modo texto): aí o greetd (WantedBy=graphical.target)
#     nunca inicia e o boot cai no TTY. Reforçamos os dois — ambos idempotentes.
enable_system_service greetd.service

default_target=$(systemctl get-default 2>/dev/null)
if [[ $default_target == graphical.target ]]; then
    pkg_status "boot: graphical.target" "= já é o padrão" "$C_DIM"
    log_entry service default-target skipped "já graphical.target"
elif sudo systemctl set-default graphical.target >/dev/null 2>&1; then
    pkg_status "boot: graphical.target" "✓ definido (era ${default_target:-?})" "$C_GREEN"
    log_entry service default-target configured "set-default graphical.target (era ${default_target:-?})"
else
    pkg_status "boot: graphical.target" "✗ falhou" "$C_RED"
    log_entry service default-target failed "systemctl set-default graphical.target"
fi

# 2) Sincroniza tema + WALLPAPER (o login passa a mostrar seu wallpaper atual).
#    O `dms greeter sync` pode falhar sem deixar razão no resumo — capturamos a
#    saída (mostrada ao vivo via tee, p/ o prompt do sudo continuar visível) e
#    extraímos a última linha de erro para o status e o log.
sync_out=$(mktemp)
dms greeter sync -y 2>&1 | tee "$sync_out"
sync_rc=${PIPESTATUS[0]}
if (( sync_rc == 0 )); then
    pkg_status "greeter: tema + wallpaper" "✓ sincronizado" "$C_GREEN"
    log_entry greeter sync configured "tema/wallpaper sincronizados"
else
    # Última linha significativa (fatal/erro), sem códigos de cor ANSI.
    reason=$(sed 's/\x1b\[[0-9;]*m//g' "$sync_out" | grep -iE 'fatal|error|erro|fail' | tail -1 | sed 's/^[[:space:]]*//')
    pkg_status "greeter: tema + wallpaper" "! ${reason:-verifique 'dms greeter sync' (rc=$sync_rc)}" "$C_YELLOW"
    log_entry greeter sync failed "${reason:-dms greeter sync (rc=$sync_rc)}"
fi
rm -f "$sync_out"

# 3) Auto-unlock do keyring no login (gnome-keyring). O DMS gerencia só
#    u2f/fprintd no PAM do greetd; adicionamos o pam_gnome_keyring num bloco
#    próprio (fora do bloco do DMS, idempotente) — o system-login não o tem.
PAM=/etc/pam.d/greetd
MARK=">>> dotfiles gnome-keyring"
if [[ -f $PAM ]] || sudo test -f "$PAM"; then
    if sudo grep -qF "$MARK" "$PAM"; then
        pkg_status "greetd PAM: keyring" "= já presente" "$C_DIM"
        log_entry greeter keyring skipped "pam_gnome_keyring"
    else
        sudo tee -a "$PAM" >/dev/null <<'PAMEOF'

# >>> dotfiles gnome-keyring — auto-unlock do keyring no login
auth       optional   pam_gnome_keyring.so
session    optional   pam_gnome_keyring.so auto_start
# <<< dotfiles gnome-keyring
PAMEOF
        pkg_status "greetd PAM: keyring" "✓ adicionado" "$C_GREEN"
        log_entry greeter keyring configured "pam_gnome_keyring em $PAM"
    fi
else
    c_warn "$PAM não encontrado — pulei o auto-unlock do keyring."
fi

# 4) Numlock no login: o greeter deriva do seu ~/.config/niri/config.kdl, que já
#    tem `numlock`. Verificação informativa (sem editar — herdado do config).
if grep -q '^\s*numlock' "$HOME/.config/niri/config.kdl" 2>/dev/null; then
    pkg_status "greeter: numlock" "✓ herdado do config.kdl" "$C_GREEN"
    log_entry greeter numlock configured "herdado do config.kdl do niri"
else
    c_warn "numlock não está no config.kdl do niri — adicione em input{keyboard{numlock}}."
fi

cat <<'EOF'

──────────────────────────────────────────────────────────────────────
⚠️  ANTES DE REINICIAR: teste o login.
    Mantenha um TTY aberto (Ctrl+Alt+F3) por segurança.
    Pré-visualizar/testar:  dms greeter status
    Reverter para o DM anterior:  dms greeter uninstall

Wallpaper dinâmico: o greeter mostra o wallpaper atual após `dms greeter sync`.
A re-sincronização é AUTOMÁTICA: o path unit `dms-greeter-resync.path` (systemd
user, habilitado pelo 4-symlinks.sh) observa o session.json do DMS e roda
`dms greeter sync` quando o wallpaper muda.
──────────────────────────────────────────────────────────────────────
EOF
