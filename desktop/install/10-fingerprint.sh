#!/usr/bin/env bash
# 10-fingerprint.sh — Sensor de digital (fprintd), se houver leitor no note
#
# Detecta o leitor via fprintd (D-Bus, Manager.GetDevices). Se existir:
#   - garante fprintd/libfprint,
#   - cadastra uma digital (interativo — encoste o dedo),
#   - a digital no lock e no greeter do DMS vem dos toggles enableFprint /
#     greeterEnableFprint (settings.json versionado, via D-Bus — sem PAM),
#   - opcional: sudo por digital (pam_fprintd em /etc/pam.d/sudo, com senha
#     como fallback automático).
# Em máquina sem leitor (ex.: desktop), sai sem alterar nada. Idempotente.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

SETTINGS="$HOME/.config/DankMaterialShell/settings.json"

# 1) fprintd/libfprint (idempotente — necessários até p/ detectar o leitor).
repo_install fprintd libfprint

# 2) Há leitor? O Manager do fprintd lista os devices por D-Bus (read-only).
#    "ao 0" = array vazio (nenhum device reconhecido pelo driver).
devices=$(busctl call net.reactivated.Fprint /net/reactivated/Fprint/Manager \
          net.reactivated.Fprint.Manager GetDevices 2>/dev/null)
if [[ -z $devices || $devices == "ao 0" ]]; then
    pkg_status "leitor de digital" "= nenhum detectado (pulando)" "$C_DIM"
    log_entry fingerprint reader skipped "nenhum leitor via fprintd"
    c_info "Sem leitor reconhecido. Se o note tem um, veja se precisa de driver (ex.: libfprint-2-tod1-*)."
    return 0 2>/dev/null || exit 0
fi
pkg_status "leitor de digital" "✓ detectado" "$C_GREEN"
log_entry fingerprint reader configured "leitor reconhecido pelo fprintd"

# 3) Cadastro (interativo). Só se ainda não houver digital cadastrada.
if fprintd-list "$USER" 2>/dev/null | grep -q 'has fingers enrolled'; then
    n=$(fprintd-list "$USER" 2>/dev/null | grep -c ' - #')
    pkg_status "digital cadastrada" "= $n dedo(s) já cadastrado(s)" "$C_DIM"
    log_entry fingerprint enroll skipped "$n dedo(s)"
elif [[ -t 0 && -t 1 ]]; then
    c_info "Cadastro de digital: encoste e levante o dedo várias vezes quando pedir."
    printf 'Cadastrar uma digital agora? [S/n]: '
    read -r ans
    if [[ ! $ans =~ ^[nN]$ ]]; then
        if fprintd-enroll "$USER"; then
            pkg_status "digital cadastrada" "✓ 1 dedo (right-index)" "$C_GREEN"
            log_entry fingerprint enroll configured "fprintd-enroll"
        else
            pkg_status "digital cadastrada" "✗ cadastro falhou" "$C_RED"
            log_entry fingerprint enroll failed "fprintd-enroll"
        fi
    else
        pkg_status "digital cadastrada" "= pulado (a pedido)" "$C_DIM"
        log_entry fingerprint enroll skipped "usuário pulou o cadastro"
    fi
else
    c_warn "sem TTY — pulei o cadastro. Rode 'fprintd-enroll' depois."
    log_entry fingerprint enroll skipped "sem TTY"
fi

# 4) Digital no lock e no greeter do DMS (herdado do settings.json). O DMS fala
#    com o fprintd por D-Bus — não usa PAM. Verificação informativa.
for key in enableFprint greeterEnableFprint; do
    if grep -q "\"$key\": true" "$SETTINGS" 2>/dev/null; then
        pkg_status "DMS: $key" "✓ herdado do settings.json" "$C_GREEN"
        log_entry fingerprint "$key" configured "true"
    else
        c_warn "$key não está true no settings.json — re-linke com 4-symlinks.sh."
        log_entry fingerprint "$key" skipped "$key != true"
    fi
done

# 5) sudo por digital (opcional). pam_fprintd 'sufficient' ANTES do system-auth:
#    tenta a digital e cai na senha se falhar/cancelar. Bloco marcado (idempotente).
#    Nota: o CachyOS (chwd) já pode ter adicionado o pam_fprintd — nesse caso
#    detectamos QUALQUER linha do módulo e não duplicamos.
PAM=/etc/pam.d/sudo
MODULE=$(find /usr/lib -name 'pam_fprintd.so' 2>/dev/null | head -1)
if [[ -z $MODULE ]]; then
    c_warn "pam_fprintd.so não encontrado — pulei o sudo por digital."
    log_entry fingerprint sudo-pam skipped "pam_fprintd.so ausente"
elif sudo grep -q 'pam_fprintd\.so' "$PAM" 2>/dev/null; then
    pkg_status "sudo: digital (PAM)" "= já presente (chwd/dotfiles)" "$C_DIM"
    log_entry fingerprint sudo-pam skipped "pam_fprintd já em $PAM"
elif [[ -t 0 && -t 1 ]]; then
    printf 'Habilitar digital no sudo (senha continua como fallback)? [S/n]: '
    read -r ans
    if [[ ! $ans =~ ^[nN]$ ]]; then
        tmp=$(mktemp)
        # Insere o bloco logo após a linha "#%PAM-1.0" (antes das linhas auth).
        awk '
            { print }
            /^#%PAM-1.0/ && !ins {
                print "# >>> dotfiles fprintd — digital antes da senha (fallback automático)"
                print "auth       sufficient pam_fprintd.so"
                print "# <<< dotfiles fprintd"
                ins = 1
            }
            END { if (!ins) exit 3 }
        ' "$PAM" >"$tmp"
        if [[ $? -eq 0 && -s $tmp ]] && sudo cp "$tmp" "$PAM"; then
            pkg_status "sudo: digital (PAM)" "✓ habilitado" "$C_GREEN"
            log_entry fingerprint sudo-pam configured "pam_fprintd sufficient em $PAM"
        else
            pkg_status "sudo: digital (PAM)" "✗ falhou (arquivo inalterado)" "$C_RED"
            log_entry fingerprint sudo-pam failed "não consegui editar $PAM"
        fi
        rm -f "$tmp"
    else
        pkg_status "sudo: digital (PAM)" "= pulado (a pedido)" "$C_DIM"
        log_entry fingerprint sudo-pam skipped "usuário pulou o sudo por digital"
    fi
else
    pkg_status "sudo: digital (PAM)" "= pulado (sem TTY)" "$C_DIM"
    log_entry fingerprint sudo-pam skipped "sem TTY"
fi
