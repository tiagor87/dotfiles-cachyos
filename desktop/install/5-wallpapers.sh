#!/usr/bin/env bash
# 5-wallpapers.sh — Biblioteca de wallpapers para o DMS (matugen Material You)
#
# O DMS não tem uma "pasta de biblioteca" configurável: o seletor abre um file
# browser e a ciclagem percorre os wallpapers DA MESMA PASTA do wallpaper atual.
# Então "configurar bibliotecas" = montar uma pasta organizada com wallpapers.
# Aqui usamos ~/<Pictures>/Wallpapers com subpastas por coleção.
#
# Coleções grandes (Catppuccin ~363MB) são OPT-IN: rode com
#   DOTFILES_WALLPAPERS_FETCH=1 ./setup.sh   (ou exporte antes de chamar o script)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

PICTURES=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
LIB="$PICTURES/Wallpapers"
mkdir -p "$LIB"
pkg_status "biblioteca" "$LIB" "$C_DIM"

# --- Coleção local do CachyOS (sem download) — via symlink, não duplica. ------
CACHY="/usr/share/wallpapers/cachyos-wallpapers"
if [[ -d $CACHY ]]; then
    if [[ -L "$LIB/cachyos" || -e "$LIB/cachyos" ]]; then
        pkg_status "coleção: cachyos" "= já presente" "$C_DIM"
        log_entry wallpaper cachyos skipped "$LIB/cachyos"
    else
        ln -s "$CACHY" "$LIB/cachyos"
        n=$(find -L "$LIB/cachyos" -type f 2>/dev/null | wc -l)
        pkg_status "coleção: cachyos" "✓ vinculada ($n imagens)" "$C_GREEN"
        log_entry wallpaper cachyos configured "$LIB/cachyos → $CACHY"
    fi
fi

# --- Coleção Catppuccin (curada) — OPT-IN (download ~363MB). -------------------
CATPP="$LIB/catppuccin"
if [[ ${DOTFILES_WALLPAPERS_FETCH:-0} == 1 ]]; then
    if [[ -d $CATPP/.git ]]; then
        pkg_status "coleção: catppuccin" "= já clonada" "$C_DIM"
        log_entry wallpaper catppuccin skipped "$CATPP"
    elif git clone --depth 1 https://github.com/zhichaoh/catppuccin-wallpapers "$CATPP" >/dev/null 2>&1; then
        n=$(find "$CATPP" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l)
        pkg_status "coleção: catppuccin" "✓ clonada ($n imagens)" "$C_GREEN"
        log_entry wallpaper catppuccin configured "$CATPP ($n imagens)"
    else
        pkg_status "coleção: catppuccin" "✗ falhou (sem rede?)" "$C_RED"
        log_entry wallpaper catppuccin failed "git clone falhou"
    fi
else
    c_info "Coleção Catppuccin não baixada (opt-in). Para incluir:"
    c_info "  DOTFILES_WALLPAPERS_FETCH=1 bash desktop/install/5-wallpapers.sh"
fi

# --- Como usar no DMS ---------------------------------------------------------
total=$(find -L "$LIB" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l)
c_ok "Biblioteca com $total wallpaper(s) em: $LIB"
c_info "No DMS: abra o seletor de wallpaper e navegue até $LIB → escolha um"
c_info "(o matugen recolore o tema). Ative 'cycling' p/ rotacionar a pasta."
