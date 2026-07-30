#!/usr/bin/env bash
# 2-symlinks.sh — Linka o config do Ghostty
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# O config do Ghostty inclui themes/dankcolors por caminho relativo à pasta
# ~/.config/ghostty (o matugen do DMS grava lá; include opcional, com "?").
symlink "$HOME/.config/ghostty/config" \
        "$DOTFILES_ROOT/terminal/ghostty/config" \
        "ghostty config"

mkdir -p "$HOME/.config/ghostty/themes"

# Valida a config (o Ghostty parseia e reporta erros sem abrir janela).
if command -v ghostty >/dev/null 2>&1; then
    if ghostty +validate-config >/dev/null 2>&1; then
        pkg_status "ghostty config" "✓ válida" "$C_GREEN"
        log_entry config "ghostty config" configured "config carregada sem erros"
    else
        pkg_status "ghostty config" "! avisos (veja: ghostty +validate-config)" "$C_YELLOW"
        log_entry config "ghostty config" configured "rode 'ghostty +validate-config'"
    fi
fi
