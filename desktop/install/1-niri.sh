#!/usr/bin/env bash
# 1-niri.sh — Instala o niri (compositor Wayland) + utilitários da sessão
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Pacotes: o compositor + tudo que o config.kdl referencia
# (terminal, launcher, lock, mídia, clipboard) + portais e suporte a X11.
# Os symlinks dos configs ficam no passo 4-symlinks.sh (padrão dotfiles-windows).
repo_install \
    niri \
    fuzzel \
    swaylock \
    swaybg \
    playerctl \
    brightnessctl \
    xwayland-satellite \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome
