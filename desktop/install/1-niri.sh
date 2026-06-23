#!/usr/bin/env bash
# 1-niri.sh — Instala o niri (compositor Wayland) + utilitários da sessão e linka o config
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Pacotes: o compositor + tudo que o config.kdl referencia
# (terminal, launcher, lock, mídia, clipboard) + portais e suporte a X11.
repo_install \
    niri \
    alacritty \
    fuzzel \
    swaylock \
    swaybg \
    playerctl \
    brightnessctl \
    xwayland-satellite \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome

# Config do niri (já vem com o DMS integrado: waybar off, keybinds e autostart).
symlink "$HOME/.config/niri/config.kdl" \
        "$DOTFILES_ROOT/desktop/niri/config.kdl" \
        "niri config.kdl"

# Valida o config resultante.
if command -v niri >/dev/null 2>&1; then
    if niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1; then
        c_ok "Config do niri válido."
    else
        c_warn "Config do niri inválido — rode 'niri validate' para ver o erro."
        log_entry config "niri validate" failed "config inválido após symlink"
    fi
fi
