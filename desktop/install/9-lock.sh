#!/usr/bin/env bash
# 9-lock.sh — Lock da máquina via DMS (substitui o swaylock)
#
# O niri não tem locker próprio. Antes o Super+Alt+L chamava o swaylock; agora
# chama o lock nativo do DankMaterialShell (`dms ipc call lock lock`) — a MESMA
# UI do greeter (wallpaper dinâmico, relógio, campo de senha e, se habilitada,
# a digital via 10-fingerprint.sh). O binding vive no config.kdl versionado e o
# `lockBeforeSuspend` no settings.json. Este script valida o wiring e remove o
# swaylock (agora sem uso). Idempotente.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

if ! command -v dms >/dev/null 2>&1; then
    c_err "binário 'dms' não encontrado — rode o 2-dms.sh primeiro."
    return 0 2>/dev/null || exit 0
fi

NIRI_CONF="$HOME/.config/niri/config.kdl"
SETTINGS="$HOME/.config/DankMaterialShell/settings.json"

# 1) Binding do lock (herdado do config.kdl versionado). Verificação informativa.
if grep -qF 'spawn "dms" "ipc" "call" "lock" "lock"' "$NIRI_CONF" 2>/dev/null; then
    pkg_status "niri: bind de lock → DMS" "✓ herdado do config.kdl" "$C_GREEN"
    log_entry lock bind configured "dms ipc call lock lock"
elif grep -qF 'spawn "swaylock"' "$NIRI_CONF" 2>/dev/null; then
    pkg_status "niri: bind de lock" "! ainda aponta p/ swaylock — rode 4-symlinks.sh" "$C_YELLOW"
    log_entry lock bind failed "config ainda usa swaylock (re-linke o config.kdl)"
else
    c_warn "não encontrei o bind de lock no $NIRI_CONF."
    log_entry lock bind failed "bind de lock ausente em $NIRI_CONF"
fi

# 2) Sanidade: o lock nativo responde via IPC? Só dá p/ checar com o shell
#    rodando — no meio do setup ele pode estar offline (aí não é falha).
if dms ipc call lock status >/dev/null 2>&1; then
    pkg_status "dms lock: IPC" "✓ responde" "$C_GREEN"
    log_entry lock ipc configured "dms ipc call lock status ok"
else
    pkg_status "dms lock: IPC" "= shell offline (ok — sobe no boot)" "$C_DIM"
    log_entry lock ipc skipped "shell DMS offline durante o setup"
fi

# 3) Lock antes de suspender (herdado do settings.json). Verificação informativa.
if grep -q '"lockBeforeSuspend": true' "$SETTINGS" 2>/dev/null; then
    pkg_status "DMS: lock antes de suspender" "✓ herdado do settings.json" "$C_GREEN"
    log_entry lock suspend configured "lockBeforeSuspend=true"
else
    c_warn "lockBeforeSuspend não está true no settings.json — re-linke com 4-symlinks.sh."
    log_entry lock suspend skipped "lockBeforeSuspend != true"
fi

# 4) Remove o swaylock (agora sem uso). Guarda de dependência + confirmação:
#    se algo depender dele, mantém; sem TTY, mantém. Reversível (reinstalar).
if pacman -Q swaylock >/dev/null 2>&1; then
    reqby=$(LC_ALL=C pacman -Qi swaylock 2>/dev/null \
            | awk -F': ' '/Required By/{print $2}' | xargs)
    if [[ -n $reqby && $reqby != "None" ]]; then
        pkg_status "swaylock" "= mantido (requerido por: $reqby)" "$C_DIM"
        log_entry lock swaylock skipped "requerido por $reqby"
    elif [[ -t 0 && -t 1 ]]; then
        printf 'Remover o swaylock (substituído pelo lock do DMS)? [S/n]: '
        read -r ans
        if [[ ! $ans =~ ^[nN]$ ]]; then
            if sudo pacman -Rns --noconfirm swaylock >/dev/null 2>&1; then
                pkg_status "swaylock" "✓ removido" "$C_GREEN"
                log_entry lock swaylock configured "removido (substituído pelo DMS)"
            else
                pkg_status "swaylock" "✗ falha ao remover" "$C_RED"
                log_entry lock swaylock failed "pacman -Rns swaylock"
            fi
        else
            pkg_status "swaylock" "= mantido (a pedido)" "$C_DIM"
            log_entry lock swaylock skipped "usuário optou por manter"
        fi
    else
        pkg_status "swaylock" "= mantido (sem TTY p/ confirmar)" "$C_DIM"
        log_entry lock swaylock skipped "sem TTY"
    fi
fi
