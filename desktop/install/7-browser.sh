#!/usr/bin/env bash
# 7-browser.sh — Instala o Helium Browser + suporte a DRM (Widevine)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Helium está no repositório CachyOS; Widevine vem do AUR.
repo_install helium-browser-bin
aur_install chromium-widevine
