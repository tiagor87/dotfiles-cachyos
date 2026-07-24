#!/usr/bin/env bash
# 11-posting.sh — Posting (cliente de API HTTP no terminal, TUI)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Posting é um app Python (Textual) e só existe no AUR — o pacote já traz as
# dependências python-* empacotadas, então não precisa de `uv tool`.
aur_install posting

c_info "Uso:  posting            (coleções em ~/.local/share/posting/ ; config: posting locate config)"
