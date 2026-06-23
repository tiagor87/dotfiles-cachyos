#!/usr/bin/env bash
# 2-symlinks.sh — Linka o .zshrc
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

symlink "$HOME/.zshrc" \
        "$DOTFILES_ROOT/shell/zsh/.zshrc" \
        ".zshrc"
