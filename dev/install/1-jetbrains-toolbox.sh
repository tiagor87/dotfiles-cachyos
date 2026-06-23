#!/usr/bin/env bash
# 1-jetbrains-toolbox.sh — JetBrains Toolbox (gerencia Rider, IntelliJ, etc.)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Toolbox vem do AUR; ele instala/atualiza as IDEs da JetBrains depois.
aur_install jetbrains-toolbox
