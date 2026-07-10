#!/usr/bin/env bash
# 1-wezterm.sh — Instala o WezTerm + fonte Nerd Font + node (equalize de panes)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# WezTerm + JetBrainsMono Nerd Font (ícones/ligaduras usados no wezterm.lua).
# nodejs roda o equalize.js (Ctrl+Shift+E distribui os panes da aba).
repo_install wezterm ttf-jetbrains-mono-nerd nodejs

# As cores dinâmicas do WezTerm vêm do DMS via matugen (matugenTemplateWezterm),
# gerando ~/.config/wezterm/colors/dank-theme.toml. Garante que está ligado.
if command -v dms >/dev/null 2>&1; then
    c_info "Cores dinâmicas: ative 'Wezterm' nos templates matugen do DMS (já ligado por padrão)."
fi
