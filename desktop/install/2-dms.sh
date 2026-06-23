#!/usr/bin/env bash
# 2-dms.sh — Instala o DankMaterialShell (quickshell) e suas dependências
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# dms-shell já puxa quickshell + dgop. O resto são features do DMS
# (cores dinâmicas, clipboard, OSD de brilho, áudio, ícones, sons).
repo_install \
    dms-shell \
    matugen \
    wl-clipboard \
    cliphist \
    cava \
    qt6-multimedia \
    inter-font \
    cups-pk-helper \
    kimageformats

# Fonte de ícones Material Symbols (AUR).
aur_install ttf-material-symbols-variable-git

# O autostart é feito pelo próprio config.kdl do niri
# (`spawn-at-startup "dms" "run"`), então NÃO habilitamos o dms.service aqui
# — evita subir o shell duas vezes.
c_info "Autostart do DMS é via spawn-at-startup no config do niri (sem dms.service)."

# Diagnóstico opcional.
if command -v dms >/dev/null 2>&1; then
    c_info "Rode 'dms doctor' para checar dependências/warnings do DMS."
fi
