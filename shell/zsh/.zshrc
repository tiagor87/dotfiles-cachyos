# .zshrc — gerenciado pelo dotfiles-cachyos (linkado p/ ~/.zshrc)

# ─── Oh My Zsh ───────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# fzf: o plugin do OMZ já carrega os keybindings (Ctrl+R, Ctrl+T, Alt+C).
plugins=(git fzf sudo)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ─── Plugins via pacman (Arch) — syntax-highlighting deve vir por ÚLTIMO ──────
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

# ─── fzf (fallback caso o plugin do OMZ não carregue) ────────────────────────
if command -v fzf >/dev/null 2>&1 && [[ -z ${_fzf_loaded:-} ]]; then
    if fzf --zsh >/dev/null 2>&1; then
        eval "$(fzf --zsh)"
    else
        [[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
        [[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
    fi
fi

# ─── Ferramentas (carrega só se instaladas) ──────────────────────────────────
command -v mise    >/dev/null 2>&1 && eval "$(mise activate zsh)"
command -v zoxide  >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# ─── Aliases ─────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
