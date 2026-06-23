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

# Autostart via serviço systemd de usuário (recomendado pelo DMS). O config.kdl
# do niri NÃO usa spawn-at-startup pro DMS (deixa o spawn comentado) justamente
# para o autostart ficar a cargo do dms.service — evita subir o shell duas vezes.
if command -v dms >/dev/null 2>&1; then
    enable_user_service dms.service
    c_info "Rode 'dms doctor' para checar dependências/warnings do DMS."
else
    c_warn "binário 'dms' não encontrado — pulei o enable do dms.service."
    log_entry service dms.service failed "dms não instalado"
fi
