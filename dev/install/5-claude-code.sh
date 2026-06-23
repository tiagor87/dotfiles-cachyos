#!/usr/bin/env bash
# 5-claude-code.sh — Claude Code + perfis isolados (estrutura do dotfiles-windows)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

repo_install claude-code jq

# CLAUDE.md global (metodologia) → ~/.claude/CLAUDE.md
symlink "$HOME/.claude/CLAUDE.md" \
        "$DOTFILES_ROOT/dev/claude/CLAUDE.md" \
        "CLAUDE.md (global)"

# Função `c` (perfis isolados) → ~/.config/claude/claude.zsh
symlink "$HOME/.config/claude/claude.zsh" \
        "$DOTFILES_ROOT/dev/claude/claude.zsh" \
        "claude.zsh (função c)"

# Skills custom do repo → ~/.claude/skills/<skill> (se houver)
if [[ -d $DOTFILES_ROOT/dev/claude/skills ]]; then
    for skill in "$DOTFILES_ROOT"/dev/claude/skills/*/; do
        [[ -d $skill ]] || continue
        symlink "$HOME/.claude/skills/$(basename "$skill")" "${skill%/}" "skill: $(basename "$skill")"
    done
fi

# Liga o source da função no .zshrc versionado (idempotente).
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if [[ -f $ZSHRC ]] && ! grep -q 'claude/claude.zsh' "$ZSHRC"; then
    {
        echo ''
        echo '# Claude Code com perfis isolados (função c)'
        echo '[[ -r ~/.config/claude/claude.zsh ]] && source ~/.config/claude/claude.zsh'
    } >>"$ZSHRC"
    pkg_status ".zshrc" "✓ source da função c" "$C_GREEN"
    log_entry dev "claude .zshrc" configured "source claude.zsh"
fi

# Seed do perfil 'default' (WorkDir = ~/.claude, o config padrão) se ausente.
PJSON="$HOME/.claude_profiles.json"
if [[ ! -f $PJSON ]]; then
    jq -n --arg w "$HOME/.claude" '{default: {WorkDir:$w, Args:""}}' >"$PJSON"
    pkg_status "perfis Claude" "✓ seed (default → ~/.claude)" "$C_GREEN"
    log_entry dev "claude profiles" configured "seed default"
else
    pkg_status "perfis Claude" "= já existe ($(jq -r 'keys|join(\", \")' "$PJSON" 2>/dev/null))" "$C_DIM"
    log_entry dev "claude profiles" skipped "$PJSON"
fi

# Linka o CLAUDE.md global dentro do WorkDir de cada perfil registrado.
if [[ -f $PJSON ]]; then
    while IFS= read -r wd; do
        [[ -n $wd ]] || continue
        mkdir -p "$wd"
        [[ -e $wd/CLAUDE.md ]] || ln -s "$HOME/.claude/CLAUDE.md" "$wd/CLAUDE.md"
    done < <(jq -r '.[].WorkDir // empty' "$PJSON")
fi

c_info "Uso:  c            (seletor de perfil + roda o Claude na pasta atual)"
c_info "      c add work   |   c ls   |   c rm <nome>"
