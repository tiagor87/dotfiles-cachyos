#!/usr/bin/env bash
# 2-docker-desktop.sh — Docker Desktop + fix do login (credential store via pass/GPG)
#
# No Linux, o Docker Desktop guarda o token de login com o credential helper
# "pass" (docker-credential-desktop == docker-credential-pass). Sem uma chave
# GPG + `pass init`, o "Sign in" autentica no navegador mas FALHA ao salvar a
# credencial — parece que não loga. Este script garante GPG + pass (idempotente).
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

aur_install docker-desktop
repo_install pass gnupg   # backend de credenciais do Docker Desktop

# Autostart no login (serviço systemd de usuário). O pacote já costuma vir
# enabled; garantimos de forma idempotente.
enable_user_service docker-desktop.service

# 1) Chave GPG (o pass precisa de uma chave de criptografia). Sem passphrase
#    para o helper salvar/ler o token sem prompt a cada login.
keyid=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/{print $5; exit}')
if [[ -z $keyid ]]; then
    c_info "Gerando chave GPG (sem passphrase) para o pass/Docker Desktop..."
    host=$(hostname 2>/dev/null || echo localhost)
    gpg --batch --gen-key >/dev/null 2>&1 <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $(whoami)
Name-Comment: pass / docker-desktop
Name-Email: $(whoami)@${host}
Expire-Date: 0
%commit
EOF
    keyid=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/{print $5; exit}')
fi

if [[ -z $keyid ]]; then
    pkg_status "GPG key" "✗ não criada" "$C_RED"
    log_entry dev "GPG key" failed "gpg --gen-key falhou"
    return 0 2>/dev/null || exit 0
fi
pkg_status "GPG key" "✓ $keyid" "$C_GREEN"
log_entry dev "GPG key" configured "$keyid"

# 2) Inicializa o pass com essa chave.
if [[ -f $HOME/.password-store/.gpg-id ]]; then
    pkg_status "pass" "= já inicializado" "$C_DIM"
    log_entry dev pass skipped "$(cat "$HOME/.password-store/.gpg-id" 2>/dev/null)"
elif pass init "$keyid" >/dev/null 2>&1; then
    pkg_status "pass" "✓ init ($keyid)" "$C_GREEN"
    log_entry dev pass configured "pass init $keyid"
else
    pkg_status "pass" "✗ init falhou" "$C_RED"
    log_entry dev pass failed "pass init $keyid"
fi

c_info "Reinicie o Docker Desktop e faça Sign in de novo — o token agora persiste."

# ---------------------------------------------------------------------------
# 3) Limites de recursos da VM
# ---------------------------------------------------------------------------
# No Linux o Docker Desktop roda uma VM QEMU (linuxkit). Por padrão ela sobe com
# `-smp <todos os cores>`: num laptop de 12 threads a VM disputa CPU com o
# desktop e a digitação no terminal engasga (PSI cpu alto). Os limites moram em
# ~/.docker/desktop/settings-store.json (Cpus, MemoryMiB, DiskSizeMiB) e são
# lidos pelo backend no START — só valem após reiniciar o Docker Desktop.
DD_CPUS=${DD_CPUS:-4}
DD_MEMORY_MIB=${DD_MEMORY_MIB:-4096}   # 4 GiB
DD_DISK_MIB=${DD_DISK_MIB:-131072}     # 128 GiB
# Caminhos sobrescrevíveis por env (permite testar sem tocar na config real).
DD_SETTINGS="${DD_SETTINGS:-$HOME/.docker/desktop/settings-store.json}"
DD_DISK="${DD_DISK:-$HOME/.docker/desktop/vms/0/data/Docker.raw}"

repo_install jq   # edição cirúrgica do settings-store.json (preserva as outras chaves)
command -v jq >/dev/null 2>&1 || {
    c_err "jq ausente — não consigo ajustar os limites do Docker Desktop."
    log_entry dev "Docker limites" failed "jq ausente"
    return 0 2>/dev/null || exit 0
}

# DiskSizeMiB é um TETO do arquivo esparso Docker.raw, não uma reserva: reduzi-lo
# não libera espaço nem CPU. E encolher abaixo do que já está alocado faz o
# Docker Desktop recriar o disco — perde imagens, containers e volumes. Só
# aplicamos o teto quando os dados atuais caibem nele.
dd_disk_used_mib=0
if [[ -f $DD_DISK ]]; then
    dd_disk_used_mib=$(( $(du -B1 "$DD_DISK" 2>/dev/null | awk '{print $1}') / 1048576 ))
fi

mkdir -p "$(dirname "$DD_SETTINGS")"
[[ -f $DD_SETTINGS ]] || echo '{}' >"$DD_SETTINGS"
jq -e . "$DD_SETTINGS" >/dev/null 2>&1 || {
    c_err "$DD_SETTINGS não é JSON válido — não vou sobrescrever."
    log_entry dev "Docker limites" failed "settings-store.json inválido"
    return 0 2>/dev/null || exit 0
}

# Monta o filtro do jq só com as chaves que realmente mudam (idempotência).
dd_filter=""; dd_changed=()
dd_set_key() { # dd_set_key <chave> <valor-desejado> <rótulo>
    local key="$1" want="$2" label="$3" cur
    cur=$(jq -r --arg k "$key" '.[$k] // empty' "$DD_SETTINGS")
    if [[ $cur == "$want" ]]; then
        pkg_status "$label" "= já em $want" "$C_DIM"
        log_entry dev "$label" skipped "$want"
        return
    fi
    dd_filter+="${dd_filter:+ | }.${key} = ${want}"
    dd_changed+=("$label: ${cur:-default} → $want")
}

dd_set_key Cpus       "$DD_CPUS"       "Docker Cpus"
dd_set_key MemoryMiB  "$DD_MEMORY_MIB" "Docker MemoryMiB"

# Teto efetivo hoje: a chave, se existir; senão o tamanho VIRTUAL do Docker.raw.
dd_cap_mib=$(jq -r '.DiskSizeMiB // empty' "$DD_SETTINGS")
if [[ -z $dd_cap_mib && -f $DD_DISK ]]; then
    dd_cap_mib=$(( $(du -B1 --apparent-size "$DD_DISK" 2>/dev/null | awk '{print $1}') / 1048576 ))
fi

if (( dd_disk_used_mib > DD_DISK_MIB )); then
    # Os dados nem caibem no teto novo — recusa direto.
    c_warn "Docker.raw já tem ${dd_disk_used_mib} MiB alocados, acima do teto de ${DD_DISK_MIB} MiB."
    c_warn "  Mantendo o DiskSizeMiB atual — encolher aqui faria o Docker Desktop recriar o disco (perde imagens/volumes)."
    c_warn "  Libere espaço (\`docker system prune -a\`) e rode este script de novo para aplicar o teto."
    pkg_status "Docker DiskSizeMiB" "= mantido (dados excedem o teto)" "$C_YELLOW"
    log_entry dev "Docker DiskSizeMiB" skipped "alocado ${dd_disk_used_mib}MiB > teto ${DD_DISK_MIB}MiB"
elif [[ -n $dd_cap_mib ]] && (( dd_cap_mib > DD_DISK_MIB )); then
    # Os dados caibem, mas é uma REDUÇÃO de teto: o Docker Desktop pode recriar o
    # Docker.raw no próximo start. Reduzir o teto não libera espaço (o arquivo é
    # esparso: só ${dd_disk_used_mib} MiB estão de fato em disco), então o ganho é
    # nenhum e o risco é perder imagens/volumes. Exige confirmação explícita.
    c_warn "Reduzir o teto de disco ${dd_cap_mib} MiB → ${DD_DISK_MIB} MiB pode fazer o Docker Desktop"
    c_warn "  RECRIAR o Docker.raw no próximo start, apagando imagens, containers e volumes."
    c_warn "  O arquivo é esparso: só ${dd_disk_used_mib} MiB estão realmente em disco — baixar o teto não libera espaço."
    if [[ -t 0 ]] && read -rp "  Reduzir o teto mesmo assim? [s/N] " dd_ans && [[ $dd_ans =~ ^[SsYy]$ ]]; then
        dd_set_key DiskSizeMiB "$DD_DISK_MIB" "Docker DiskSizeMiB"
    else
        pkg_status "Docker DiskSizeMiB" "= mantido (redução não confirmada)" "$C_YELLOW"
        log_entry dev "Docker DiskSizeMiB" skipped "redução ${dd_cap_mib}→${DD_DISK_MIB}MiB não confirmada"
    fi
else
    dd_set_key DiskSizeMiB "$DD_DISK_MIB" "Docker DiskSizeMiB"
fi

if [[ -z $dd_filter ]]; then
    c_info "Limites do Docker Desktop já aplicados — nada a fazer."
else
    dd_tmp=$(mktemp)
    if jq "$dd_filter" "$DD_SETTINGS" >"$dd_tmp" && jq -e . "$dd_tmp" >/dev/null 2>&1; then
        cp "$DD_SETTINGS" "$DD_SETTINGS.bak"
        mv "$dd_tmp" "$DD_SETTINGS"
        for change in "${dd_changed[@]}"; do
            pkg_status "${change%%:*}" "✓ ${change#*: }" "$C_GREEN"
            log_entry dev "${change%%:*}" configured "${change#*: }"
        done
        c_info "Backup do settings-store anterior em $DD_SETTINGS.bak"
    else
        rm -f "$dd_tmp"
        pkg_status "Docker limites" "✗ falhou ao escrever" "$C_RED"
        log_entry dev "Docker limites" failed "jq não conseguiu editar o settings-store.json"
    fi
fi

# O backend só relê os limites no start. NÃO reiniciamos sozinhos: um restart
# mata containers em execução (estado compartilhado). Avisa e deixa a cargo do
# usuário; se o Docker Desktop estiver parado, o próximo start já sobe limitado.
if pgrep -f '/com\.docker\.backend' >/dev/null 2>&1; then
    c_warn "Docker Desktop está rodando — os limites valem após:  docker desktop restart"
    c_warn "  (isso PARA os containers em execução; rode quando for seguro)"
else
    c_info "Docker Desktop parado — o próximo start já sobe com os limites."
fi
c_info "Conferir depois do restart:  pgrep -af qemu-system | grep -o '\\-smp [0-9]*\\|\\-m [0-9]*'"
