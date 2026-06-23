#!/usr/bin/env bash
# 1-windows-mounts.sh — Monta unidades Windows (NTFS via ntfs3) com SEGURANÇA.
#
# Proteção contra quebrar o boot/login (o requisito central):
#   nofail                       → mount que falha NÃO derruba o boot (systemd só loga e segue)
#   x-systemd.automount          → nem monta no boot: monta sob demanda, no 1º acesso
#   x-systemd.device-timeout=10s → não espera o disco eternamente
#   + backup do /etc/fstab e validação (findmnt --verify) antes de aplicar; se
#     o fstab ficar inválido, restaura o backup e aborta.
#
# Interativo (fzf): você escolhe QUAIS unidades montar. Sem TTY/fzf, só lista.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

FSTAB=/etc/fstab
# nofail é o que protege o login; uid/gid/umask dão acesso ao seu usuário.
OPTS="rw,nosuid,nodev,nofail,noatime,x-systemd.automount,x-systemd.device-timeout=10s,uid=$(id -u),gid=$(id -g),umask=022,windows_names"

# ntfs3 é do kernel; ntfs-3g traz o ntfsfix (limpar flag "dirty"). Útil, opcional.
repo_install ntfs-3g

# Garante que o módulo ntfs3 está disponível.
if ! grep -qw ntfs3 /proc/filesystems 2>/dev/null && ! modinfo ntfs3 >/dev/null 2>&1; then
    c_err "Driver ntfs3 não disponível no kernel atual — abortando."
    log_entry storage ntfs3 failed "módulo ntfs3 ausente"
    return 0 2>/dev/null || exit 0
fi

# Lista as partições NTFS (lsblk -P = pares chave=\"valor\", lida com labels vazios/espaços).
mapfile -t ntfs_lines < <(
    lsblk -P -o NAME,FSTYPE,LABEL,UUID,SIZE | while read -r line; do
        eval "$line"
        [[ ${FSTYPE:-} == ntfs ]] || continue
        printf '%s\t%s\t%s\t%s\n' "$UUID" "${LABEL:-}" "$SIZE" "$NAME"
    done
)
if [[ ${#ntfs_lines[@]} -eq 0 ]]; then
    c_info "Nenhuma partição NTFS encontrada."
    return 0 2>/dev/null || exit 0
fi

# Sem TTY/fzf: só lista e ensina a fazer manual.
if [[ ! -t 0 || ! -t 1 ]] || ! command -v fzf >/dev/null 2>&1; then
    c_info "Partições NTFS (adicione ao $FSTAB com 'nofail' p/ não quebrar o boot):"
    printf '  %s\n' "${ntfs_lines[@]}"
    return 0 2>/dev/null || exit 0
fi

# Seletor: mostra "label (size) [/dev/name] UUID"; campo 1 (UUID) é o que usamos.
selection=$(
    for l in "${ntfs_lines[@]}"; do
        IFS=$'\t' read -r uuid label size name <<<"$l"
        printf '%s\t%-14s %-7s /dev/%s\n' "$uuid" "${label:-(sem rótulo)}" "$size" "$name"
    done | fzf --multi --reverse --height=60% --with-nth=2.. \
        --prompt="Unidades Windows p/ montar — TAB marca várias > " \
        --header=$'As pequenas sem rótulo (~700M) sao Recovery; a grande sem rótulo costuma ser o C:.\nMontar o C: pode ficar somente-leitura se o Windows estiver com Fast Startup/hibernado.'
)
[[ -n $selection ]] || { c_info "Nada selecionado."; return 0 2>/dev/null || exit 0; }

# Backup do fstab antes de qualquer escrita.
sudo -v || { c_err "sudo recusado — abortando."; return 0 2>/dev/null || exit 0; }
BACKUP="${FSTAB}.bak.$(date +%Y%m%d-%H%M%S 2>/dev/null || echo manual)"
sudo cp -a "$FSTAB" "$BACKUP"
c_ok "Backup do fstab: $BACKUP"

added=0
while IFS=$'\t' read -r uuid rest; do
    [[ -n $uuid ]] || continue
    # nome do ponto de montagem: rótulo (sanitizado) ou win-<dev>
    label=$(printf '%s' "$rest" | awk '{print $1}')
    if [[ -z $label || $label == "(sem" ]]; then
        dev=$(printf '%s' "$rest" | grep -oE '/dev/\S+'); mp="/mnt/win-$(basename "$dev")"
    else
        mp="/mnt/$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"
    fi

    if grep -q "UUID=$uuid" "$FSTAB"; then
        pkg_status "$mp" "= já no fstab" "$C_DIM"; log_entry storage "$mp" skipped "$uuid"
        continue
    fi
    sudo mkdir -p "$mp"
    echo "UUID=$uuid  $mp  ntfs3  $OPTS  0 0" | sudo tee -a "$FSTAB" >/dev/null
    pkg_status "$mp" "✓ adicionado (UUID=$uuid)" "$C_GREEN"
    log_entry storage "$mp" configured "ntfs3 nofail+automount"
    added=$((added+1))
done <<<"$selection"

# Validação: se o fstab ficou inválido, restaura o backup.
if ! findmnt --verify --fstab >/dev/null 2>&1; then
    c_err "fstab inválido após edição! Restaurando backup."
    findmnt --verify --fstab 2>&1 | grep -iE 'err|warn' | head
    sudo cp -a "$BACKUP" "$FSTAB"
    log_entry storage fstab failed "inválido — backup restaurado"
    return 0 2>/dev/null || exit 0
fi
c_ok "fstab válido (findmnt --verify)."

sudo systemctl daemon-reload 2>/dev/null || true
[[ $added -gt 0 ]] && c_info "Pronto. As unidades montam sob demanda no 1º acesso (automount)."
c_info "Se montar somente-leitura: desative o Fast Startup no Windows (ou ntfsfix -d)."
