#!/usr/bin/env bash
# 5-wallpapers.sh — Biblioteca de wallpapers (PASTA ÚNICA) para o DMS
#
# O DMS cicla os wallpapers DA MESMA PASTA do atual — então, com tudo numa
# pasta só, a ciclagem percorre a coleção inteira. Por isso a biblioteca é
# PLANA: ~/<Pictures>/Wallpapers/<colecao>_<arquivo>.
#
# Coleções remotas (anime/games/Catppuccin) são OPT-IN por causa do tamanho:
#   DOTFILES_WALLPAPERS_FETCH=1 ./setup.sh   (ou exporte antes de rodar)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

PICTURES=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
LIB="$PICTURES/Wallpapers"
mkdir -p "$LIB"
pkg_status "biblioteca" "$LIB" "$C_DIM"

EXTS=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp')

have_prefix() { compgen -G "$LIB/$1"'_*' >/dev/null 2>&1; }

# Copia imagens de <src> para a raiz do LIB, nome = <name>_<caminho-relativo>
# (com / virando _ p/ evitar colisão). Ignora assets/pages dos repos.
flatten_into() {
    local src="$1" name="$2" f rel
    find "$src" -type f \( "${EXTS[@]}" \) \
        -not -path '*/assets/*' -not -path '*/pages/*' -not -path '*/.github/*' -print0 |
    while IFS= read -r -d '' f; do
        rel=${f#"$src"/}; rel=${rel//\//_}
        cp -n "$f" "$LIB/${name}_${rel}" 2>/dev/null || true
    done
}

count_prefix() { find "$LIB" -maxdepth 1 -type f -name "$1"'_*' 2>/dev/null | wc -l; }

# --- Coleção local do CachyOS (sem download). ---------------------------------
CACHY="/usr/share/wallpapers/cachyos-wallpapers"
if [[ -d $CACHY ]]; then
    if have_prefix cachyos; then
        pkg_status "coleção: cachyos" "= já presente" "$C_DIM"
        log_entry wallpaper cachyos skipped "$(count_prefix cachyos) imagens"
    else
        flatten_into "$CACHY" cachyos
        pkg_status "coleção: cachyos" "✓ ($(count_prefix cachyos) imagens)" "$C_GREEN"
        log_entry wallpaper cachyos configured "$(count_prefix cachyos) imagens"
    fi
fi

# --- Coleções remotas — OPT-IN (clone shallow temporário → achata → limpa). ---
# Formato: "prefixo|repo github|nota"
COLLECTIONS=(
    "anime|port19x/wallpapers|anime (~46MB)"
    "aesthetic|D3Ext/aesthetic-wallpapers|anime + games + aesthetic (~629MB)"
    "catppuccin|zhichaoh/catppuccin-wallpapers|Catppuccin curado (~363MB)"
)
if [[ ${DOTFILES_WALLPAPERS_FETCH:-0} == 1 ]]; then
    for entry in "${COLLECTIONS[@]}"; do
        IFS='|' read -r name repo note <<<"$entry"
        if have_prefix "$name"; then
            pkg_status "coleção: $name" "= já presente" "$C_DIM"
            log_entry wallpaper "$name" skipped "$(count_prefix "$name") imagens"
            continue
        fi
        tmp=$(mktemp -d)
        if git clone --depth 1 "https://github.com/$repo" "$tmp" >/dev/null 2>&1; then
            flatten_into "$tmp" "$name"
            pkg_status "coleção: $name" "✓ ($(count_prefix "$name") imagens)" "$C_GREEN"
            log_entry wallpaper "$name" configured "$repo → $(count_prefix "$name") imagens"
        else
            pkg_status "coleção: $name" "✗ falhou (sem rede?)" "$C_RED"
            log_entry wallpaper "$name" failed "git clone $repo falhou"
        fi
        rm -rf "$tmp"
    done
else
    c_info "Coleções de anime/games/Catppuccin são opt-in. Para baixar:"
    c_info "  DOTFILES_WALLPAPERS_FETCH=1 bash desktop/install/5-wallpapers.sh"
fi

# --- Como usar no DMS ---------------------------------------------------------
total=$(find "$LIB" -maxdepth 1 -type f \( "${EXTS[@]}" \) 2>/dev/null | wc -l)
c_ok "Biblioteca com $total wallpaper(s) (pasta única) em: $LIB"
c_info "No DMS: seletor de wallpaper → $LIB → escolha um (matugen recolore)."
c_info "Ative 'cycling' para rotacionar TODA a pasta."
