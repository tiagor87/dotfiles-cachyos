#!/usr/bin/env bash
# 2-symlinks.sh — Linka o environment.d do agente SSH
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Define SSH_AUTH_SOCK para a sessão (gcr-ssh-agent).
symlink "$HOME/.config/environment.d/10-ssh-agent.conf" \
        "$DOTFILES_ROOT/security/environment.d/10-ssh-agent.conf" \
        "environment.d/10-ssh-agent.conf"
