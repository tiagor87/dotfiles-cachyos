#!/usr/bin/env bash
# 5-claude-code.sh — Claude Code via Headroom (sem perfis), com opção de setup limpo.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

repo_install claude-code jq

# ---------------------------------------------------------------------------
# Setup limpo
# ---------------------------------------------------------------------------
# Config DERIVADA: tudo aqui é regerado por este script e pelo 8-claude-hud.sh,
# então remover é seguro. Só é oferecido quando algum destes já existe (ou seja,
# numa re-execução) — em máquina limpa não há o que perguntar.
CLEAN_TARGETS=(
    "$HOME/.claude/settings.json"   # hooks + statusLine
    "$HOME/.claude/plugins"         # cache de plugins (claude-hud etc.)
    "$HOME/.claude/hooks"           # hooks — o `headroom wrap` reinstala o do rtk
    "$HOME/.claude_profiles.json"   # perfis — conceito removido
)

# NUNCA removidos, nem no setup limpo:
#   ~/.claude/.credentials.json  → login (limpar forçaria novo `claude login`)
#   ~/.claude/projects/          → histórico de sessões + memória
#   ~/.claude/CLAUDE.md          → symlink pro repo (recriado abaixo de qualquer forma)
# Pastas de perfil antigas (~/.claude.<nome>) também não são tocadas: podem
# conter o login de OUTRA conta. Só avisamos que ficaram para trás.

DO_CLEAN=0
FOUND_STATE=0
for p in "${CLEAN_TARGETS[@]}"; do
    [[ -e $p ]] && { FOUND_STATE=1; break; }
done

if [[ $FOUND_STATE -eq 1 ]]; then
    if [[ -t 0 && -t 1 ]]; then
        c_warn "Já existe configuração do Claude Code nesta máquina."
        printf '  %sSetup limpo REMOVE (e regera):%s\n' "$C_YELLOW" "$C_RESET"
        for p in "${CLEAN_TARGETS[@]}"; do
            [[ -e $p ]] && printf '    %s− %s%s\n' "$C_DIM" "$p" "$C_RESET"
        done
        printf '  %sPreserva: login, histórico de sessões (projects/) e CLAUDE.md.%s\n' "$C_DIM" "$C_RESET"
        printf '\n  Fazer setup LIMPO? [s/N]: '
        read -r answer
        [[ $answer =~ ^[SsYy]$ ]] && DO_CLEAN=1
    else
        c_info "Sem TTY — mantenho a config atual (setup incremental)."
    fi
fi

if [[ $DO_CLEAN -eq 1 ]]; then
    for p in "${CLEAN_TARGETS[@]}"; do
        [[ -e $p ]] || continue
        rm -rf "$p"
        pkg_status "$(basename "$p")" "✓ removido (setup limpo)" "$C_YELLOW"
        log_entry dev "limpeza: $(basename "$p")" configured "removido: $p"
    done
else
    [[ $FOUND_STATE -eq 1 ]] && c_info "Setup incremental — config existente preservada."
fi

# Pastas de perfil órfãs: avisa, não remove (podem ter login de outra conta).
shopt -s nullglob
STALE_PROFILES=("$HOME"/.claude.*/)
shopt -u nullglob
if [[ ${#STALE_PROFILES[@]} -gt 0 ]]; then
    c_warn "Perfis não são mais usados. Pastas antigas ficaram para trás (remova à mão se quiser):"
    for p in "${STALE_PROFILES[@]}"; do printf '    %s%s%s\n' "$C_DIM" "$p" "$C_RESET"; done
fi

# ---------------------------------------------------------------------------
# Symlinks + shell
# ---------------------------------------------------------------------------

# CLAUDE.md global (metodologia) → ~/.claude/CLAUDE.md
symlink "$HOME/.claude/CLAUDE.md" \
        "$DOTFILES_ROOT/dev/claude/CLAUDE.md" \
        "CLAUDE.md (global)"

# Função `c` (Claude via Headroom) → ~/.config/claude/claude.zsh
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

# Solta o HEADROOM_PROXY_URL fixo do MCP do headroom (herança do setup por base
# URL, que dava uma porta por perfil). Com o `wrap` quem escolhe a porta é o
# próprio wrap, e o MCP herda a env do processo: um valor fixo aqui aponta o
# headroom_retrieve pra um proxy morto.
MCPJSON="$HOME/.claude/.claude.json"
if [[ -f $MCPJSON ]] && jq -e '.mcpServers.headroom.env.HEADROOM_PROXY_URL' "$MCPJSON" >/dev/null 2>&1; then
    tmp=$(mktemp)
    if jq 'del(.mcpServers.headroom.env.HEADROOM_PROXY_URL)' "$MCPJSON" >"$tmp" && mv "$tmp" "$MCPJSON"; then
        pkg_status "MCP headroom" "✓ porta fixa removida (herda do wrap)" "$C_GREEN"
        log_entry dev "MCP headroom" configured "HEADROOM_PROXY_URL removido de $MCPJSON"
    else
        rm -f "$tmp"
        pkg_status "MCP headroom" "✗ falhou ao limpar a porta fixa" "$C_RED"
        log_entry dev "MCP headroom" failed "jq falhou em $MCPJSON"
    fi
fi

# Liga o source da função no .zshrc versionado (idempotente).
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if [[ -f $ZSHRC ]] && ! grep -q 'claude/claude.zsh' "$ZSHRC"; then
    {
        echo ''
        echo '# Claude Code via Headroom (função c)'
        echo '[[ -r ~/.config/claude/claude.zsh ]] && source ~/.config/claude/claude.zsh'
    } >>"$ZSHRC"
    pkg_status ".zshrc" "✓ source da função c" "$C_GREEN"
    log_entry dev "claude .zshrc" configured "source claude.zsh"
fi

c_info "Uso:  c            (Claude Code na pasta atual, via Headroom, janela de 1M)"
c_info "      c --no-hr    (sem Headroom, direto na API)"
