#!/usr/bin/env bash
# 10-headroom-wrappers.sh — Codex, codex-fugu e Antigravity CLI (agy) via Headroom + YOLO
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Codex CLI (pacote oficial via pacman).
repo_install openai-codex

# antigravity-cli já é instalado via AUR em dev/install/3-cli-tools.sh.

# codex-fugu não é instalável de forma declarativa: é o bootstrap pessoal do
# SakanaAI/fugu (~/.fugu), interativo e pede API key própria — não dá pra
# automatizar sem embutir segredo no repo. Só avisa se ainda não foi feito.
if [[ ! -d "$HOME/.fugu" ]]; then
    c_warn "codex-fugu: ~/.fugu não existe. Bootstrap manual (pede API key):"
    c_warn "  git clone https://github.com/SakanaAI/fugu.git ~/.fugu && ~/.fugu/scripts/install.sh"
fi

# Funções `codex` / `codex-fugu` → ~/.config/codex/codex.zsh
symlink "$HOME/.config/codex/codex.zsh" \
        "$DOTFILES_ROOT/dev/codex/codex.zsh" \
        "codex.zsh (funções codex, codex-fugu)"

# Função `agy` → ~/.config/antigravity/agy.zsh
symlink "$HOME/.config/antigravity/agy.zsh" \
        "$DOTFILES_ROOT/dev/antigravity/agy.zsh" \
        "agy.zsh (função agy)"

# Liga o source das funções no .zshrc versionado (idempotente).
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if [[ -f $ZSHRC ]] && ! grep -q 'codex/codex.zsh' "$ZSHRC"; then
    {
        echo ''
        echo '# Codex CLI + codex-fugu via Headroom (YOLO, sem perfis)'
        echo '[[ -r ~/.config/codex/codex.zsh ]] && source ~/.config/codex/codex.zsh'
    } >>"$ZSHRC"
    pkg_status ".zshrc" "✓ source das funções codex/codex-fugu" "$C_GREEN"
    log_entry dev "codex .zshrc" configured "source codex.zsh"
fi
if [[ -f $ZSHRC ]] && ! grep -q 'antigravity/agy.zsh' "$ZSHRC"; then
    {
        echo ''
        echo '# Antigravity CLI (agy) em modo YOLO'
        echo '[[ -r ~/.config/antigravity/agy.zsh ]] && source ~/.config/antigravity/agy.zsh'
    } >>"$ZSHRC"
    pkg_status ".zshrc" "✓ source da função agy" "$C_GREEN"
    log_entry dev "agy .zshrc" configured "source agy.zsh"
fi

c_info "Uso:  codex [args]   |   codex-fugu [args]   |   agy [args]"
c_info "      Sempre em modo YOLO (sem sandbox / sem confirmação). Abra um novo shell p/ valer."
