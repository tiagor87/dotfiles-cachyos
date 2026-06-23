#!/usr/bin/env bash
# 3-sddm.sh — Instala o SDDM (display manager) e habilita no boot
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# SDDM + deps para o greeter Qt6 (usado por temas modernos).
repo_install sddm qt6-svg qt6-declarative

# Avisa se já existe outro display manager habilitado (evita conflito).
current_dm=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)
if [[ -n $current_dm && $current_dm != sddm ]]; then
    c_warn "Outro display manager já habilitado: ${current_dm}. Desabilite-o antes:"
    c_warn "  sudo systemctl disable ${current_dm}.service"
fi

# Habilita o SDDM (sobrescreve o display-manager.service ao habilitar).
enable_system_service sddm.service

c_info "No login, escolha a sessão 'niri' no canto da tela do SDDM."
