#!/usr/bin/env bash
# 2-plymouth.sh — Splash de boot (Plymouth) com tema square_hud (adi1090x)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# O Plymouth e o hook do mkinitcpio já vêm no CachyOS; só trocamos o tema.
aur_install plymouth-theme-square-hud-git

# Descobre o nome do tema instalado (square_hud) sem hardcode frágil.
theme=""
for d in /usr/share/plymouth/themes/*square*hud* /usr/share/plymouth/themes/*square*; do
    [[ -d $d ]] && { theme=$(basename "$d"); break; }
done

if [[ -z $theme ]]; then
    c_warn "Tema square-hud não encontrado em /usr/share/plymouth/themes/."
    log_entry config plymouth failed "tema não instalado"
    return 0 2>/dev/null || exit 0
fi

current=$(plymouth-set-default-theme 2>/dev/null || true)
if [[ $current == "$theme" ]]; then
    pkg_status "plymouth: $theme" "= já ativo" "$C_DIM"
    log_entry config "plymouth tema" skipped "$theme"
else
    # -R reconstrói o initramfs (mkinitcpio -P) para embutir o tema.
    c_info "Aplicando tema '$theme' e reconstruindo o initramfs (pode demorar)..."
    if sudo plymouth-set-default-theme -R "$theme"; then
        pkg_status "plymouth: $theme" "✓ aplicado (+ initramfs)" "$C_GREEN"
        log_entry config "plymouth tema" configured "$theme (initramfs reconstruído)"
    else
        pkg_status "plymouth: $theme" "✗ falhou" "$C_RED"
        log_entry config "plymouth tema" failed "plymouth-set-default-theme -R $theme"
    fi
fi

c_info "Pré-visualizar sem reiniciar:  sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth --quit"
