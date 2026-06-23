#!/usr/bin/env bash
# 3-symlinks.sh — Linka os configs do kitty e do Herdr
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# kitty.conf inclui theme.conf e dank-*.conf por caminho absoluto (${HOME}),
# então basta linkar os dois arquivos versionados; o DMS escreve os
# dank-*.conf na mesma pasta (auto-gerados, não versionados).
symlink "$HOME/.config/kitty/kitty.conf" \
        "$DOTFILES_ROOT/terminal/kitty/kitty.conf" \
        "kitty.conf"

symlink "$HOME/.config/kitty/theme.conf" \
        "$DOTFILES_ROOT/terminal/kitty/theme.conf" \
        "kitty theme.conf"

# Herdr: herda fonte/cores do kitty via tema "terminal".
symlink "$HOME/.config/herdr/config.toml" \
        "$DOTFILES_ROOT/terminal/herdr/config.toml" \
        "herdr config.toml"

# Valida a config (kitty +runpy lê e reporta erros sem abrir janela).
if command -v kitty >/dev/null 2>&1; then
    if err=$(kitty +runpy 'from kitty.config import load_config; load_config(["'"$HOME"'/.config/kitty/kitty.conf"]); print("ok")' 2>&1) && [[ $err == *ok* ]]; then
        pkg_status "kitty config" "✓ válida" "$C_GREEN"
        log_entry config "kitty config" configured "config carregada sem erros"
    else
        pkg_status "kitty config" "! avisos (veja: kitty --debug-config)" "$C_YELLOW"
        log_entry config "kitty config" configured "rode 'kitty --debug-config' se algo destoar"
    fi
fi
