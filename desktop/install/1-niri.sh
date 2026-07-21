#!/usr/bin/env bash
# 1-niri.sh — Instala o niri (compositor Wayland) + utilitários da sessão
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Pacotes: o compositor + tudo que o config.kdl referencia
# (terminal, launcher, mídia, clipboard) + portais e suporte a X11.
# O lock da máquina é o do DMS (`dms ipc call lock lock`, ver 9-lock.sh), não o
# swaylock. Os symlinks dos configs ficam no 4-symlinks.sh (padrão dotfiles-win).
repo_install \
    niri \
    fuzzel \
    swaybg \
    playerctl \
    brightnessctl \
    xwayland-satellite \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome
