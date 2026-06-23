#!/usr/bin/env bash
# 3-cli-tools.sh — Runtimes/CLIs de dev: bun + AWS CLI v2
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# bun (runtime/JS) e aws-cli-v2 — ambos no repo oficial (extra).
repo_install bun aws-cli-v2
