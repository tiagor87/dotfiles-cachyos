#!/usr/bin/env bash
# greeter-resync.sh — re-sincroniza o greeter do DMS com o wallpaper atual.
#
# Pensado para ser o "Script Path" do plugin WallpaperWatcherDaemon do DMS:
# ele roda este script a cada troca de wallpaper, passando o novo caminho como
# $1 (o `dms greeter sync` lê o wallpaper atual sozinho, então $1 é ignorado).
#
# Caminho estável (linkado pelo 4-symlinks.sh):
#   ~/.config/DankMaterialShell/greeter-resync.sh
#
# Observação: `dms greeter sync` precisa de privilégio para escrever em
# /etc/greetd. O DMS instala uma polkit policy (cli-policy.json) no
# `dms greeter install`; se mesmo assim pedir senha, configure uma regra
# passwordless para a ação do dms — senão a resync abrirá um prompt.
set -uo pipefail

command -v dms >/dev/null 2>&1 || exit 0
# Só faz sentido se o greeter do DMS estiver instalado/configurado.
dms greeter status >/dev/null 2>&1 || exit 0

exec dms greeter sync -y
