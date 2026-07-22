#!/usr/bin/env bash
# 8-keyboard.sh — Layout de teclado (X11/Wayland via localectl): BR ABNT2 ou
# US International
#
# O config.kdl do niri deixa o bloco `xkb {}` vazio de propósito: nesse caso
# o niri busca rules/model/layout/variant/options do org.freedesktop.locale1
# (localectl). Se o "X11 Layout" estiver unset, o niri cai no fallback "us"
# puro — sem acentos. Este script define o X11 Layout via
# `localectl set-x11-keymap`, cobrindo os dois casos comuns:
#   - BR ABNT2 nativo (acentos diretos)
#   - US International (dead keys: acento agudo, til, trema etc.)
#
# Ambos são layouts/variantes registrados no dataset do sistema, então o
# localectl os aceita direto — sem depender de nenhuma variante xkb custom.
#
# Interativo (pede a escolha); sem TTY, pula sem alterar nada.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

if [[ ! -t 0 || ! -t 1 ]]; then
    c_warn "sem TTY — pulei a seleção de layout de teclado."
    log_entry keyboard xkb skipped "sem TTY"
    return 0 2>/dev/null || exit 0
fi

current=$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/{print $2}' | xargs)
default=1
[[ $current == "us" ]] && default=2

printf '\n%sLayout de teclado:%s\n' "$C_CYAN" "$C_RESET"
printf '  [1] Português (BR ABNT2)\n'
printf '  [2] US International (dead keys: acentos, til, trema)\n'
printf 'Selecione [1/2] (Enter mantém a opção %d): ' "$default"
read -r choice
choice=${choice:-$default}

case "$choice" in
    1) LAYOUT=br MODEL=abnt2 VARIANT="" LABEL="BR ABNT2" ;;
    2) LAYOUT=us MODEL=pc105 VARIANT=intl LABEL="US International" ;;
    *) c_err "opção inválida: $choice"; log_entry keyboard xkb failed "opção inválida"; return 1 2>/dev/null || exit 1 ;;
esac

sudo -v || { c_err "sudo recusado — abortando."; return 1 2>/dev/null || exit 1; }

if [[ -n $VARIANT ]]; then
    out=$(sudo localectl set-x11-keymap "$LAYOUT" "$MODEL" "$VARIANT" 2>&1)
else
    out=$(sudo localectl set-x11-keymap "$LAYOUT" "$MODEL" 2>&1)
fi

if [[ $(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/{print $2}' | xargs) == "$LAYOUT" ]]; then
    pkg_status "layout de teclado" "✓ $LABEL" "$C_GREEN"
    log_entry keyboard xkb configured "$LAYOUT/$MODEL/$VARIANT"
    c_warn "reinicie o niri (ou a sessão) para o novo layout valer."
else
    pkg_status "layout de teclado" "✗ falhou" "$C_RED"
    log_entry keyboard xkb failed "$out"
fi
