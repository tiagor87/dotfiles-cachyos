#!/usr/bin/env bash
# 1-limine-theme.sh — Garante a paleta Catppuccin Mocha no /boot/limine.conf
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

CONF="/boot/limine.conf"

# Chaves de cor gerenciadas (só existem na seção global do limine.conf — nunca
# dentro das entradas de kernel —, então o sed por chave é seguro). NÃO mexemos
# em term_background/wallpaper para preservar o splash do CachyOS.
declare -A COLORS=(
    [term_palette]="1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    [term_palette_bright]="585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    [term_foreground]="cdd6f4"
    [term_foreground_bright]="cdd6f4"
)

if ! sudo test -f "$CONF"; then
    c_err "$CONF não encontrado — o CachyOS usa Limine? Pulando."
    log_entry config "limine theme" failed "$CONF ausente"
    return 0 2>/dev/null || exit 0
fi

# Já está tudo correto?
need_change=0
for k in "${!COLORS[@]}"; do
    cur=$(sudo grep -E "^${k}:" "$CONF" | head -1 | sed -E "s/^${k}:[[:space:]]*//")
    [[ $cur == "${COLORS[$k]}" ]] || need_change=1
done

if [[ $need_change -eq 0 ]]; then
    pkg_status "limine: paleta Catppuccin Mocha" "= já aplicada" "$C_DIM"
    log_entry config "limine theme" skipped "paleta já correta"
    return 0 2>/dev/null || exit 0
fi

# Backup antes de qualquer escrita.
BACKUP="${CONF}.bak.$(date +%Y%m%d-%H%M%S 2>/dev/null || echo manual)"
sudo cp -a "$CONF" "$BACKUP"
c_ok "Backup do limine.conf: $BACKUP"

# Conta entradas de kernel antes (sanidade: não podem mudar).
entries_before=$(sudo grep -cE '^[[:space:]]*/' "$CONF")

for k in "${!COLORS[@]}"; do
    if sudo grep -qE "^${k}:" "$CONF"; then
        sudo sed -i -E "s|^${k}:.*|${k}: ${COLORS[$k]}|" "$CONF"
    else
        # chave ausente: insere antes da 1ª entrada (seção global)
        sudo sed -i -E "0,/^[[:space:]]*\//s||${k}: ${COLORS[$k]}\n&|" "$CONF"
    fi
done

entries_after=$(sudo grep -cE '^[[:space:]]*/' "$CONF")
if [[ $entries_before -ne $entries_after ]]; then
    c_err "Contagem de entradas mudou ($entries_before → $entries_after)! Restaurando backup."
    sudo cp -a "$BACKUP" "$CONF"
    pkg_status "limine: paleta Catppuccin Mocha" "✗ revertido" "$C_RED"
    log_entry config "limine theme" failed "entradas alteradas — backup restaurado"
    return 0 2>/dev/null || exit 0
fi

pkg_status "limine: paleta Catppuccin Mocha" "✓ aplicada" "$C_GREEN"
log_entry config "limine theme" configured "paleta Catppuccin Mocha (backup em $BACKUP)"
