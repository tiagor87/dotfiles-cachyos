#!/usr/bin/env bash
# 6-profile-picture.sh — Foto de perfil do usuário (AccountsService → usada pelo DMS)
#
# O DMS lê a foto do AccountsService (IconFile). Setamos a própria foto via
# D-Bus — o polkit permite "change-own-user-data" para o usuário ativo, então
# NÃO precisa de sudo. Idempotente: pula se a foto atual já for esta imagem.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

IMG="$DOTFILES_ROOT/desktop/dms/profile.png"
if [[ ! -f $IMG ]]; then
    c_warn "Imagem não encontrada: $IMG — pulei a foto de perfil."
    return 0 2>/dev/null || exit 0
fi
command -v gdbus >/dev/null 2>&1 || { c_warn "gdbus ausente — pulei."; return 0 2>/dev/null || exit 0; }

obj=$(gdbus call --system --dest org.freedesktop.Accounts \
        --object-path /org/freedesktop/Accounts \
        --method org.freedesktop.Accounts.FindUserByName "$(whoami)" 2>/dev/null |
      grep -oE '/org/freedesktop/Accounts/User[0-9]+')
if [[ -z $obj ]]; then
    c_warn "AccountsService indisponível — pulei a foto de perfil."
    return 0 2>/dev/null || exit 0
fi

# Já é esta imagem? (o IconFile é uma cópia em /var/lib/AccountsService/icons/<user>)
current_icon="/var/lib/AccountsService/icons/$(whoami)"
if [[ -f $current_icon ]] && cmp -s "$IMG" "$current_icon"; then
    pkg_status "foto de perfil" "= já definida" "$C_DIM"
    log_entry profile picture skipped "$current_icon"
    return 0 2>/dev/null || exit 0
fi

if gdbus call --system --dest org.freedesktop.Accounts --object-path "$obj" \
       --method org.freedesktop.Accounts.User.SetIconFile "$IMG" >/dev/null 2>&1; then
    pkg_status "foto de perfil" "✓ definida (AccountsService)" "$C_GREEN"
    log_entry profile picture configured "$IMG → $current_icon"
else
    pkg_status "foto de perfil" "✗ falhou (polkit?)" "$C_RED"
    log_entry profile picture failed "SetIconFile recusado"
fi
