#!/usr/bin/env bash
# 1-zsh.sh — zsh + Oh My Zsh + fzf + zoxide (+ plugins de autosuggestions/syntax-highlight)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

repo_install zsh fzf zsh-autosuggestions zsh-syntax-highlighting zoxide

# Oh My Zsh — instalação não-interativa que NÃO troca o shell nem mexe no
# ~/.zshrc (gerenciamos o .zshrc por symlink no 2-symlinks.sh).
if [[ -d $HOME/.oh-my-zsh ]]; then
    pkg_status "oh-my-zsh" "= já instalado" "$C_DIM"
    log_entry shell oh-my-zsh skipped "$HOME/.oh-my-zsh"
elif command -v curl >/dev/null 2>&1 && \
     RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
       "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
       "" --unattended >/dev/null 2>&1; then
    pkg_status "oh-my-zsh" "✓ instalado" "$C_GREEN"
    log_entry shell oh-my-zsh configured "instalado (unattended)"
else
    pkg_status "oh-my-zsh" "✗ falhou (sem rede/curl?)" "$C_RED"
    log_entry shell oh-my-zsh failed "install.sh falhou"
fi

# Define o zsh como shell padrão (chsh pede a sua senha).
ZSH_BIN=$(command -v zsh || true)
if [[ -n $ZSH_BIN && $SHELL != "$ZSH_BIN" ]]; then
    if chsh -s "$ZSH_BIN"; then
        pkg_status "shell padrão" "✓ zsh (relogin p/ valer)" "$C_GREEN"
        log_entry shell "shell padrão" configured "chsh -s $ZSH_BIN"
    else
        pkg_status "shell padrão" "! troque manual: chsh -s $ZSH_BIN" "$C_YELLOW"
        log_entry shell "shell padrão" failed "chsh recusado"
    fi
elif [[ $SHELL == "$ZSH_BIN" ]]; then
    pkg_status "shell padrão" "= já é zsh" "$C_DIM"
    log_entry shell "shell padrão" skipped zsh
fi
