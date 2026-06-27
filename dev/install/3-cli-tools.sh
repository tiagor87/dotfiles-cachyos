#!/usr/bin/env bash
# 3-cli-tools.sh — Runtimes/CLIs de dev: bun + AWS CLI v2 + Terraform + Antigravity CLI
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# bun (runtime/JS), aws-cli-v2, terraform — repos oficiais (extra).
repo_install bun aws-cli-v2 terraform

# antigravity-cli — disponível apenas no AUR.
aur_install antigravity-cli
