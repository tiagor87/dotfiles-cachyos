#!/usr/bin/env bash
# 5-starship.sh — starship (prompt cross-shell; assume o PROMPT no lugar do tema do OMZ)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# O quickstart do site é `curl -sS https://starship.rs/install.sh | sh`, que joga
# um binário solto em /usr/local/bin. O pacote está no repo oficial (extra) —
# mesma versão, atualiza com o sistema e não escapa do pacman.
repo_install starship

command -v /usr/bin/starship >/dev/null 2>&1 || {
    c_err "starship não instalado — o resto da configuração foi pulado."
    return 0 2>/dev/null || exit 0
}

# --- Instalação solta do install.sh (se houver) --------------------------------
if [[ -x /usr/local/bin/starship ]]; then
    c_warn "/usr/local/bin/starship (do install.sh) vem antes no PATH e sombreia o do pacman."
    c_warn "  remova com:  sudo rm /usr/local/bin/starship"
    log_entry shell "starship standalone" skipped "/usr/local/bin/starship sombreia /usr/bin"
fi

# --- Integração com o zsh ------------------------------------------------------
# O `eval "$(starship init zsh)"` está no .zshrc versionado, DEPOIS do
# oh-my-zsh.sh: quem escreve o PROMPT por último ganha. O ZSH_THEME segue no
# .zshrc só como FALLBACK (máquina sem starship) — não é conflito.
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if grep -q 'starship init zsh' "$ZSHRC" 2>/dev/null; then
    pkg_status "starship no .zshrc" "= já configurado" "$C_DIM"
    log_entry shell "starship .zshrc" skipped "eval starship init zsh"
else
    c_warn "Falta o \`eval \"\$(starship init zsh)\"\` em $ZSHRC — o prompt segue no ZSH_THEME."
    log_entry shell "starship .zshrc" failed "linha de init ausente"
fi

# --- Config --------------------------------------------------------------------
# Sem config versionado, de propósito: valem os DEFAULTS do starship (ele não
# precisa nem criar o ~/.config/starship.toml). Pra trocar o visual:
#   starship preset --list
#   starship preset catppuccin-powerline -o ~/.config/starship.toml
# Se customizar, mova o arquivo pra shell/starship/starship.toml e linke aqui
# com `symlink`, como o config do atuin — aí ele passa a ser versionado.
if [[ -e $HOME/.config/starship.toml ]]; then
    pkg_status "starship.toml" "= config local (não versionado)" "$C_DIM"
    log_entry shell "starship.toml" skipped "$HOME/.config/starship.toml (fora do repo)"
else
    pkg_status "starship.toml" "= sem config (defaults do starship)" "$C_DIM"
    log_entry shell "starship.toml" skipped "defaults (nenhum arquivo criado)"
fi

c_info "Prompt:  starship (defaults) · presets: starship preset --list"
c_info "         diagnóstico: starship explain  |  starship timings"
