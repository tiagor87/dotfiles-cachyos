#!/usr/bin/env bash
# 1-wezterm.sh — Instala o WezTerm + Ghostty + fonte Nerd Font + node (equalize)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# WezTerm + Ghostty (mesma fonte e mesmo tema) + JetBrainsMono Nerd Font
# (ícones/ligaduras usados nos dois configs).
# nodejs roda o equalize.js (Ctrl+Shift+E distribui os panes da aba).
repo_install wezterm ghostty ttf-jetbrains-mono-nerd nodejs

# As cores dinâmicas dos dois vêm do DMS via matugen, gerando
# ~/.config/wezterm/colors/dank-theme.toml e ~/.config/ghostty/themes/dankcolors.
if command -v dms >/dev/null 2>&1; then
    c_info "Cores dinâmicas: ative 'Wezterm' e 'Ghostty' nos templates matugen do DMS (já ligados por padrão)."
fi
