#!/usr/bin/env bash
# 9-beekeeper-studio.sh — Beekeeper Studio (cliente de banco de dados, GUI)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Beekeeper Studio vem do AUR como binário pré-compilado.
aur_install beekeeper-studio-bin
