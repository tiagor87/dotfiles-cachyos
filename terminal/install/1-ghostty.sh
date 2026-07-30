#!/usr/bin/env bash
# 1-ghostty.sh — Instala o Ghostty + fonte Nerd Font
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Ghostty + JetBrainsMono Nerd Font (ícones/ligaduras usados no config).
repo_install ghostty ttf-jetbrains-mono-nerd

# As cores dinâmicas vêm do DMS via matugen, que gera o
# ~/.config/ghostty/themes/dankcolors.
if command -v dms >/dev/null 2>&1; then
    c_info "Cores dinâmicas: mantenha 'Ghostty' ligado nos templates matugen do DMS."
fi
