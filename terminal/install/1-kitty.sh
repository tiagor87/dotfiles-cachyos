#!/usr/bin/env bash
# 1-kitty.sh — Instala o kitty + fonte Nerd Font
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# kitty + JetBrainsMono Nerd Font (ícones/ligaduras usados no kitty.conf).
repo_install kitty ttf-jetbrains-mono-nerd

# As cores dinâmicas do kitty já vêm do DMS via matugen
# (matugenTemplateKitty), gerando ~/.config/kitty/dank-theme.conf e
# dank-tabs.conf. Garante que o template está ligado.
if command -v dms >/dev/null 2>&1; then
    c_info "Cores dinâmicas: ative 'Kitty' nos templates matugen do DMS (já ligado por padrão)."
fi
