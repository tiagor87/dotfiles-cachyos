#!/usr/bin/env bash
# 1-gnome-keyring.sh — Keyring (Secret Service + agente SSH) com auto-unlock
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# gnome-keyring = cofre + Secret Service; seahorse = GUI (opcional).
# libsecret e gcr-4 já costumam vir instalados no CachyOS (deps do GNOME stack).
repo_install gnome-keyring seahorse libsecret

# Agente SSH moderno: o gnome-keyring novo delega pro gcr-ssh-agent (gcr-4).
# Socket de usuário — sem sudo. O SSH_AUTH_SOCK é exportado via environment.d
# (linkado no 2-symlinks.sh) apontando para $XDG_RUNTIME_DIR/gcr/ssh.
enable_user_service gcr-ssh-agent.socket

# Integra o git ao keyring (tokens/senhas HTTPS guardados no Secret Service).
if [[ -x /usr/lib/git-core/git-credential-libsecret ]]; then
    cur=$(git config --global --get credential.helper 2>/dev/null || true)
    if [[ $cur == libsecret ]]; then
        pkg_status "git credential.helper" "= já é libsecret" "$C_DIM"
        log_entry config "git credential" skipped "libsecret"
    else
        git config --global credential.helper libsecret
        pkg_status "git credential.helper" "✓ libsecret" "$C_GREEN"
        log_entry config "git credential" configured "credential.helper=libsecret"
    fi
fi

# O auto-unlock no login já está pronto: o /etc/pam.d/sddm tem as linhas
# `-pam_gnome_keyring.so` (o prefixo `-` ativa quando o módulo existe). Instalar
# o gnome-keyring acima já as ativa — sem editar PAM.
c_info "Auto-unlock no login: ativo via pam_gnome_keyring no SDDM (sem edição)."
c_info "GUI do cofre: seahorse.  CLI: secret-tool store/lookup."
