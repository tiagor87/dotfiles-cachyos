#!/usr/bin/env bash
# 3-cloudflare-warp.sh — Cloudflare WARP (VPN / DNS 1.1.1.1) via warp-cli
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# cloudflare-warp-bin: binário oficial (warp-svc + warp-cli). Só existe no AUR.
aur_install cloudflare-warp-bin

# Daemon do WARP (serviço de sistema). O warp-cli só registra/conecta com o
# warp-svc no ar, então habilitamos E iniciamos (o enable_system_service só
# habilita; o start garante que já dá pra usar sem reboot). Idempotente.
enable_system_service warp-svc.service
if ! systemctl is-active warp-svc.service >/dev/null 2>&1; then
    if sudo systemctl start warp-svc.service >/dev/null 2>&1; then
        pkg_status "warp-svc.service" "✓ iniciado" "$C_GREEN"
        log_entry service warp-svc.service configured "systemctl start"
    else
        pkg_status "warp-svc.service" "✗ não iniciou" "$C_RED"
        log_entry service warp-svc.service failed "systemctl start falhou"
    fi
fi

# Registro da conta WARP (gratuito e anônimo). É pré-requisito do connect e é
# inofensivo — NÃO roteia tráfego sozinho (isso é o `warp-cli connect`, decisão
# do usuário). O subcomando mudou entre versões do warp-cli, então tentamos o
# nome novo e caímos no antigo; se nada rolar, só orientamos o registro manual.
command -v warp-cli >/dev/null 2>&1 || { return 0 2>/dev/null || exit 0; }

if warp-cli --accept-tos registration show >/dev/null 2>&1 \
   || warp-cli --accept-tos account >/dev/null 2>&1; then
    pkg_status "warp-cli registro" "= já registrado" "$C_DIM"
    log_entry config "warp-cli" skipped "já registrado"
elif warp-cli --accept-tos registration new >/dev/null 2>&1 \
     || warp-cli --accept-tos register >/dev/null 2>&1; then
    pkg_status "warp-cli registro" "✓ registrado" "$C_GREEN"
    log_entry config "warp-cli" configured "registration new"
else
    pkg_status "warp-cli registro" "! registre manualmente" "$C_YELLOW"
    log_entry config "warp-cli" skipped "rode: warp-cli registration new"
fi

c_info "Conectar (VPN full):  warp-cli connect     |  desconectar: warp-cli disconnect"
c_info "Só DNS (1.1.1.1):     warp-cli mode doh && warp-cli connect"
c_info "Status:               warp-cli status"
