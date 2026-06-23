#!/usr/bin/env bash
# 3-configure-zsh.sh — Configuração interativa do Oh My Zsh (tema + plugins).
#
# Edita o .zshrc VERSIONADO (fonte da verdade; o ~/.zshrc é symlink p/ ele).
# Usa fzf p/ os pickers. Sem TTY/fzf (ex.: rodando num pipe), pula sem travar.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
[[ -f $ZSHRC ]] || { c_err "$ZSHRC não encontrado."; return 0 2>/dev/null || exit 0; }

if [[ ! -t 0 || ! -t 1 ]] || ! command -v fzf >/dev/null 2>&1; then
    c_info "Config interativa do zsh pulada (sem TTY/fzf). Edite à mão em:"
    c_info "  $ZSHRC  →  ZSH_THEME=\"...\"  e  plugins=(...)"
    return 0 2>/dev/null || exit 0
fi

# --- Tema --------------------------------------------------------------------
cur_theme=$(grep -oP '^ZSH_THEME="\K[^"]*' "$ZSHRC" 2>/dev/null || echo robbyrussell)
if [[ -d $HOME/.oh-my-zsh/themes ]]; then
    mapfile -t themes < <(find "$HOME/.oh-my-zsh/themes" -name '*.zsh-theme' -printf '%f\n' | sed 's/\.zsh-theme$//' | sort)
else
    mapfile -t themes < <(printf '%s\n' robbyrussell agnoster af-magic gnzh bira fino-time half-life)
fi
theme=$(printf '%s\n' "${themes[@]}" | \
    fzf --reverse --height=45% --query="$cur_theme" \
        --prompt="Tema do zsh (Enter p/ confirmar, atual: $cur_theme) > ")
[[ -n $theme ]] || theme=$cur_theme

# --- Plugins (multi-seleção: TAB marca) --------------------------------------
cur_plugins=$(grep -oP '^plugins=\(\K[^)]*' "$ZSHRC" 2>/dev/null)
CANDIDATES=(git fzf sudo z zoxide docker docker-compose kubectl npm node python
           golang rust gh dotnet mise command-not-found colored-man-pages
           extract history web-search archlinux systemd ssh-agent)
sel=$(printf '%s\n' "${CANDIDATES[@]}" | \
    fzf --multi --reverse --height=60% \
        --prompt="Plugins — TAB p/ marcar vários (atuais: $cur_plugins) > " \
        --header="Esc sem marcar nada mantém os atuais")
if [[ -n $sel ]]; then
    plugins=$(printf '%s' "$sel" | tr '\n' ' ' | sed 's/ *$//')
else
    plugins=$cur_plugins
fi

# --- Aplica no arquivo versionado --------------------------------------------
sed -i -E "s|^ZSH_THEME=.*|ZSH_THEME=\"$theme\"|" "$ZSHRC"
sed -i -E "s|^plugins=\(.*\)|plugins=($plugins)|"  "$ZSHRC"

pkg_status "zsh config" "✓ tema=$theme | plugins=($plugins)" "$C_GREEN"
log_entry shell "zsh config" configured "ZSH_THEME=$theme; plugins=($plugins)"
c_info "Recarregue com:  exec zsh   (ou abra um novo terminal)."
