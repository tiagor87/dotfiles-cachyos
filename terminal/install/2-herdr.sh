#!/usr/bin/env bash
# 2-herdr.sh — Instala o Herdr (multiplexer de coding agents) via AUR
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Herdr não está nos repositórios oficiais — vem do AUR (pacote -bin).
aur_install herdr-bin
