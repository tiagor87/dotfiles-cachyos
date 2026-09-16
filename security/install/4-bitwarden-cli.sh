#!/usr/bin/env bash
# 4-bitwarden-cli.sh — Bitwarden CLI (`bw`) — cofre de senhas no terminal
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# bitwarden-cli está no repo oficial (extra/cachyos-extra-v3) — sem AUR.
repo_install bitwarden-cli

command -v bw >/dev/null 2>&1 || { return 0 2>/dev/null || exit 0; }

# Estado do cofre (unauthenticated | locked | unlocked). Login e unlock ficam a
# cargo do usuário: pedem senha-mestra/2FA e a sessão é por shell (BW_SESSION).
# Lê o JSON do `bw status` com sed em vez de jq — o jq não é dependência daqui.
case "$(bw status 2>/dev/null | sed -nE 's/.*"status":"([a-z]+)".*/\1/p')" in
    unlocked)          pkg_status "bw cofre" "= destrancado" "$C_DIM"
                       log_entry config bw skipped "cofre destrancado" ;;
    locked)            pkg_status "bw cofre" "= logado (trancado)" "$C_DIM"
                       log_entry config bw skipped "logado, trancado" ;;
    unauthenticated|*) pkg_status "bw cofre" "! faça login" "$C_YELLOW"
                       log_entry config bw skipped "rode: bw login" ;;
esac

c_info 'Login:    bw login              |  logout: bw logout'
c_info 'Unlock:   export BW_SESSION="$(bw unlock --raw)"   (por shell)'
c_info 'Uso:      bw list items --search <termo>  |  bw get password <id>'
