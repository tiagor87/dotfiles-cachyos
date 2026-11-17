#!/usr/bin/env bash
# 15-onorca.sh — Orca (IDE para rodar múltiplos coding agents em paralelo)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Orca (onorca.dev) vem do AUR como binário pré-compilado.
aur_install onorca-bin
