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
