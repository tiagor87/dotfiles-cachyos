#!/usr/bin/env bash
# 3-cli-tools.sh — Runtimes/CLIs de dev: bun + AWS CLI v2 + Terraform + GitHub CLI + Antigravity CLI
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# bun (runtime/JS), aws-cli-v2, terraform, github-cli — repos oficiais (extra).
repo_install bun aws-cli-v2 terraform github-cli

# antigravity-cli — disponível apenas no AUR.
aur_install antigravity-cli
