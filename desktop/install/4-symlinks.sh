#!/usr/bin/env bash
# 4-symlinks.sh — Linka os configs do repo para suas localizações reais
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

NIRI_CONF="$HOME/.config/niri/config.kdl"

# niri: config.kdl (já com o DMS integrado — waybar off, keybinds, dms.service).
symlink "$NIRI_CONF" \
        "$DOTFILES_ROOT/desktop/niri/config.kdl" \
        "niri config.kdl"

# DMS: settings.json (tema, módulos da barra, transparências...).
symlink "$HOME/.config/DankMaterialShell/settings.json" \
        "$DOTFILES_ROOT/desktop/dms/settings.json" \
        "DMS settings.json"

# O niri resolve `include "dms/..."` relativo à pasta do config (~/.config/niri/).
# Esses arquivos são AUTO-GERADOS pelo DMS e por isso NÃO são versionados. Numa
# máquina nova eles ainda não existem quando o niri sobe, o que invalidaria o
# config. Criamos stubs vazios para os includes referenciados; o DMS os
# sobrescreve com o conteúdo real no primeiro `dms run`.
if [[ -e $NIRI_CONF ]]; then
    while IFS= read -r inc; do
        target="$HOME/.config/niri/$inc"
        if [[ ! -e $target ]]; then
            mkdir -p "$(dirname "$target")"
            : >"$target"
            pkg_status "$inc" "✓ stub criado (DMS regenera)" "$C_GREEN"
            log_entry config "$inc" configured "stub vazio (auto-gerado pelo DMS)"
        fi
    done < <(grep -oP '^\s*include\s+"\K[^"]+' "$NIRI_CONF")
fi

# Valida o config resultante.
if command -v niri >/dev/null 2>&1; then
    if niri validate -c "$NIRI_CONF" >/dev/null 2>&1; then
        pkg_status "niri validate" "✓ config válido" "$C_GREEN"
        log_entry config "niri validate" configured "config válido"
    else
        pkg_status "niri validate" "✗ config inválido" "$C_RED"
        log_entry config "niri validate" failed "rode 'niri validate' para ver o erro"
    fi
fi
