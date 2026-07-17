#!/usr/bin/env bash
# 2-clock-localtime.sh — RTC em horário local (dual boot com Windows)
#
# O Windows lê o relógio de hardware (RTC) como horário LOCAL; o Linux, por
# padrão, o interpreta como UTC. Num dual boot isso faz o horário "pular" ao
# alternar os sistemas. Alinhamos o Linux ao Windows pondo o RTC em local time.
# (O systemd considera esse modo "não confiável" por causa do DST, mas o Brasil
# não usa mais horário de verão e o NTP corrige qualquer deriva.)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# timedatectl reporta "RTC in local TZ: yes/no"; idempotência sai daí.
current=$(timedatectl show --property=LocalRTC --value 2>/dev/null || echo "")

if [[ $current == "yes" ]]; then
    pkg_status "relógio: RTC local" "= já ativo" "$C_DIM"
    log_entry config "RTC local" skipped "LocalRTC=yes"
    return 0 2>/dev/null || exit 0
fi

# --adjust-system-clock reescreve o RTC agora, evitando um salto no relógio.
if sudo timedatectl set-local-rtc 1 --adjust-system-clock; then
    pkg_status "relógio: RTC local" "✓ ativado" "$C_GREEN"
    log_entry config "RTC local" configured "set-local-rtc 1"
else
    pkg_status "relógio: RTC local" "✗ falhou" "$C_RED"
    log_entry config "RTC local" failed "timedatectl set-local-rtc 1"
fi
