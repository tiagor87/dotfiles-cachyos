#!/usr/bin/env bash
# 2-symlinks.sh — Linka os configs do WezTerm e do Ghostty
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# wezterm.lua lê ~/.config/wezterm/colors/dank-theme.toml (cores Material You do
# DMS) por caminho absoluto; basta linkar os dois arquivos versionados. O DMS
# escreve o dank-theme.toml na pasta colors/ (auto-gerado, não versionado).
symlink "$HOME/.config/wezterm/wezterm.lua" \
        "$DOTFILES_ROOT/terminal/wezterm/wezterm.lua" \
        "wezterm.lua"

symlink "$HOME/.config/wezterm/equalize.js" \
        "$DOTFILES_ROOT/terminal/wezterm/equalize.js" \
        "wezterm equalize.js"

# Garante a pasta onde o matugen do DMS grava as cores dinâmicas.
mkdir -p "$HOME/.config/wezterm/colors"

# Valida a config (wezterm carrega o wezterm.lua e reporta erros sem abrir janela).
if command -v wezterm >/dev/null 2>&1; then
    if err=$(wezterm show-keys 2>&1) && [[ -n $err ]]; then
        pkg_status "wezterm config" "✓ válida" "$C_GREEN"
        log_entry config "wezterm config" configured "config carregada sem erros"
    else
        pkg_status "wezterm config" "! avisos (veja: wezterm show-keys)" "$C_YELLOW"
        log_entry config "wezterm config" configured "rode 'wezterm show-keys' se algo destoar"
    fi
fi

# O config do Ghostty inclui themes/dankcolors por caminho relativo à pasta
# ~/.config/ghostty (o matugen do DMS grava lá; include opcional, com "?").
symlink "$HOME/.config/ghostty/config" \
        "$DOTFILES_ROOT/terminal/ghostty/config" \
        "ghostty config"

mkdir -p "$HOME/.config/ghostty/themes"

# Valida a config (o Ghostty parseia e reporta erros sem abrir janela).
if command -v ghostty >/dev/null 2>&1; then
    if ghostty +validate-config >/dev/null 2>&1; then
        pkg_status "ghostty config" "✓ válida" "$C_GREEN"
        log_entry config "ghostty config" configured "config carregada sem erros"
    else
        pkg_status "ghostty config" "! avisos (veja: ghostty +validate-config)" "$C_YELLOW"
        log_entry config "ghostty config" configured "rode 'ghostty +validate-config'"
    fi
fi
