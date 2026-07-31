#!/usr/bin/env bash
# 4-atuin.sh — atuin (histórico de shell em SQLite: Ctrl+R fuzzy + sync criptografado)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# O quickstart do upstream é `curl ... | sh`, que instala um binário solto em
# ~/.atuin e mexe no ~/.zshrc. Aqui vem do repo (cachyos-extra/extra): mesma
# versão, atualiza com o resto do sistema e não escapa do pacman.
repo_install atuin

command -v /usr/bin/atuin >/dev/null 2>&1 || {
    c_err "atuin não instalado — o resto da configuração foi pulado."
    return 0 2>/dev/null || exit 0
}

# --- Instalação solta do quickstart (se houver) -------------------------------
# ~/.atuin/bin entra na FRENTE do PATH, então o binário solto sombrearia o do
# pacman e nunca mais seria atualizado. Os dados NÃO vivem ali (ficam em
# ~/.local/share/atuin), então remover ~/.atuin não perde histórico.
if [[ -x $HOME/.atuin/bin/atuin ]]; then
    if [[ -t 0 && -t 1 ]]; then
        printf 'Remover a instalação solta em ~/.atuin (sombreia o pacote do pacman)? [S/n]: '
        read -r ans
        if [[ ! $ans =~ ^[nN]$ ]]; then
            rm -rf "$HOME/.atuin"
            hash -r
            pkg_status "~/.atuin (quickstart)" "✓ removido" "$C_GREEN"
            log_entry shell "atuin standalone" configured "removido (usa /usr/bin/atuin)"
        else
            pkg_status "~/.atuin (quickstart)" "! mantido — sombreia o pacman" "$C_YELLOW"
            log_entry shell "atuin standalone" skipped "usuário optou por manter"
        fi
    else
        c_warn "~/.atuin (instalação do quickstart) sombreia /usr/bin/atuin — remova com: rm -rf ~/.atuin"
        log_entry shell "atuin standalone" skipped "sem TTY p/ confirmar remoção"
    fi
fi

# --- Config versionado --------------------------------------------------------
symlink "$HOME/.config/atuin/config.toml" \
        "$DOTFILES_ROOT/shell/atuin/config.toml" \
        "atuin config.toml"

# --- Integração com o zsh -----------------------------------------------------
# O `eval "$(atuin init zsh)"` já está no .zshrc versionado (seção Ferramentas),
# DEPOIS do fzf — quem carrega por último fica com o Ctrl+R.
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if grep -q 'atuin init zsh' "$ZSHRC" 2>/dev/null; then
    pkg_status "atuin no .zshrc" "= já configurado" "$C_DIM"
    log_entry shell "atuin .zshrc" skipped "eval atuin init zsh"
else
    c_warn "Falta o \`eval \"\$(atuin init zsh)\"\` em $ZSHRC — Ctrl+R segue no fzf."
    log_entry shell "atuin .zshrc" failed "linha de init ausente"
fi

# --- Histórico existente (só na primeira instalação) --------------------------
# `atuin import` NÃO deduplica, então só importa com o banco vazio — rodar de
# novo depois duplicaria tudo.
count=$(/usr/bin/atuin history list 2>/dev/null | wc -l)
if [[ $count -eq 0 ]]; then
    if /usr/bin/atuin import auto >/dev/null 2>&1; then
        count=$(/usr/bin/atuin history list 2>/dev/null | wc -l)
        pkg_status "histórico importado" "✓ $count comando(s)" "$C_GREEN"
        log_entry shell "atuin import" configured "$count comandos (import auto)"
    else
        pkg_status "histórico importado" "✗ falhou" "$C_RED"
        log_entry shell "atuin import" failed "atuin import auto"
    fi
else
    pkg_status "histórico" "= $count comando(s) já no banco" "$C_DIM"
    log_entry shell "atuin import" skipped "$count comandos (import não repetido)"
fi

c_info "Uso:  Ctrl+R (busca) · ↑ (histórico) · atuin stats"
# Sync é opt-in e envolve conta própria + chave — nada disso dá pra versionar.
if ! /usr/bin/atuin status 2>/dev/null | grep -qi 'username'; then
    c_info "Sync (opcional):  atuin register -u <user> -e <email>   |   atuin login -u <user>"
    c_info "                  guarde a chave (\`atuin key\`) — sem ela o histórico não volta em outra máquina."
fi
