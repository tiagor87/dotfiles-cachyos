#!/usr/bin/env bash
# 3-sddm.sh — Instala o SDDM + tema astronaut (purple_leaves) e habilita no boot
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
THEME_VARIANT="purple_leaves"

# SDDM + deps para o greeter Qt6 (usado por temas modernos).
repo_install sddm qt6-svg qt6-declarative

# Tema astronaut (AUR) — puxa as deps Qt6 restantes (5compat, multimedia-ffmpeg,
# virtualkeyboard) automaticamente.
aur_install sddm-astronaut-theme

# Fixa a variante (o tema lê metadata.desktop > ConfigFile). Reaplicado a cada
# run para sobreviver a updates do pacote, que resetam o metadata.desktop.
if [[ -f $THEME_DIR/metadata.desktop ]]; then
    if grep -q "^ConfigFile=Themes/${THEME_VARIANT}.conf$" "$THEME_DIR/metadata.desktop"; then
        pkg_status "variante ${THEME_VARIANT}" "= já selecionada" "$C_DIM"
        log_entry config "sddm variante" skipped "$THEME_VARIANT"
    elif sudo sed -i -E "s|^ConfigFile=.*|ConfigFile=Themes/${THEME_VARIANT}.conf|" "$THEME_DIR/metadata.desktop"; then
        pkg_status "variante ${THEME_VARIANT}" "✓ selecionada" "$C_GREEN"
        log_entry config "sddm variante" configured "ConfigFile=Themes/${THEME_VARIANT}.conf"
    else
        pkg_status "variante ${THEME_VARIANT}" "✗ falhou" "$C_RED"
        log_entry config "sddm variante" failed "sed em metadata.desktop falhou"
    fi
else
    c_warn "Tema astronaut não encontrado em $THEME_DIR — pulei a seleção da variante."
fi

# Seleciona o tema globalmente: copia (não linka) o conf para /etc/sddm.conf.d/.
SRC="$DOTFILES_ROOT/desktop/sddm/10-theme.conf"
DST="/etc/sddm.conf.d/10-theme.conf"
if [[ -f $DST ]] && sudo cmp -s "$SRC" "$DST"; then
    pkg_status "10-theme.conf" "= já aplicado" "$C_DIM"
    log_entry config "sddm theme.conf" skipped "$DST"
elif sudo install -Dm644 "$SRC" "$DST"; then
    pkg_status "10-theme.conf" "✓ aplicado em /etc/sddm.conf.d/" "$C_GREEN"
    log_entry config "sddm theme.conf" configured "$DST"
else
    pkg_status "10-theme.conf" "✗ falhou" "$C_RED"
    log_entry config "sddm theme.conf" failed "cópia para $DST falhou"
fi

# Avisa se já existe outro display manager habilitado (evita conflito).
current_dm=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)
if [[ -n $current_dm && $current_dm != sddm ]]; then
    c_warn "Outro display manager já habilitado: ${current_dm}. Desabilite-o antes:"
    c_warn "  sudo systemctl disable ${current_dm}.service"
fi

# Habilita o SDDM (sobrescreve o display-manager.service ao habilitar).
enable_system_service sddm.service

c_info "Tema: sddm-astronaut-theme (${THEME_VARIANT}). No login, escolha a sessão 'niri'."
c_info "Pré-visualizar: sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
