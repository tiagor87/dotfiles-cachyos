#!/usr/bin/env bash
# greeter-resync.sh — re-sincroniza o greeter do DMS com o wallpaper atual.
#
# Disparado automaticamente pelo path unit dms-greeter-resync.path (systemd
# user), que observa o session.json do DMS. Também serve como "Script Path" do
# plugin WallpaperWatcherDaemon, se preferir. Idempotente: só roda o sync quando
# o wallpaper realmente mudou (o session.json muda por vários motivos).
#
# Obs.: `dms greeter sync` escreve em /etc/greetd (privilegiado). O
# `dms greeter install` instala uma polkit policy pra isso; se ainda pedir
# senha, adicione uma regra passwordless para a ação do dms.
set -uo pipefail

command -v dms >/dev/null 2>&1 || exit 0
dms greeter status >/dev/null 2>&1 || exit 0   # só com o greeter instalado

SESSION="$HOME/.local/state/DankMaterialShell/session.json"
STAMP="${XDG_RUNTIME_DIR:-/tmp}/dms-greeter-resync.last"

# Extrai o wallpaper atual sem depender de jq.
cur=$(grep -oP '"wallpaperPath"\s*:\s*"\K[^"]*' "$SESSION" 2>/dev/null | head -1)
[[ -n $cur ]] || exit 0
[[ -f $STAMP && $(cat "$STAMP" 2>/dev/null) == "$cur" ]] && exit 0  # inalterado

printf '%s' "$cur" >"$STAMP"
exec dms greeter sync -y
