# .zshrc — gerenciado pelo dotfiles-cachyos (linkado p/ ~/.zshrc)

# ─── Oh My Zsh ───────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
# Fallback: com o starship instalado, é ele que escreve o PROMPT (mais abaixo).
ZSH_THEME="robbyrussell"
# fzf: o plugin do OMZ já carrega os keybindings (Ctrl+R, Ctrl+T, Alt+C).
plugins=(git fzf sudo z zoxide docker docker-compose kubectl npm node python golang rust gh dotnet mise command-not-found colored-man-pages extract history web-search archlinux systemd ssh-agent)
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
# atuin: histórico em SQLite. Vem DEPOIS do fzf de propósito — quem carrega por
# último fica com o Ctrl+R (o Ctrl+T/Alt+C do fzf continuam valendo).
command -v atuin   >/dev/null 2>&1 && eval "$(atuin init zsh)"
# starship: prompt. Vem DEPOIS do oh-my-zsh.sh — quem escreve o PROMPT por
# último ganha, então o ZSH_THEME acima fica só de fallback.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# ─── Aliases ─────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
# IRIS (autocomplete no TTY): envolve o shell num filho em raw mode — é comando,
# não hook, então só entra quando você chama.
command -v iris >/dev/null 2>&1 && alias i='iris'

# Claude Code via Headroom (função c)
[[ -r ~/.config/claude/claude.zsh ]] && source ~/.config/claude/claude.zsh

# ~/.local/bin no PATH (uv tools)
export PATH="$HOME/.local/bin:$PATH"

# .NET SDK (instalado via dotnet-install.sh, não pelo pacman)
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$PATH"

# Secrets e acesso a bancos (kodano) ficam em ~/.zshenv (não versionado),
# carregado pelo zsh antes deste arquivo.

# Codex CLI + codex-fugu via Headroom (YOLO)
[[ -r ~/.config/codex/codex.zsh ]] && source ~/.config/codex/codex.zsh

# Antigravity CLI (agy) em modo YOLO
[[ -r ~/.config/antigravity/agy.zsh ]] && source ~/.config/antigravity/agy.zsh
