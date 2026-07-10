#!/usr/bin/env bash
# 7-browser.sh — Instala o Brave Origin
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Brave Origin está no repositório CachyOS; o Widevine (DRM) é resolvido
# pelo próprio Brave via brave://settings, sem pacote extra do AUR.
repo_install brave-origin-bin
