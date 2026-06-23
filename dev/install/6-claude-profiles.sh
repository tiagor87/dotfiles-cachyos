#!/usr/bin/env bash
# 6-claude-profiles.sh — Pergunta/gerencia os perfis isolados do Claude Code
# durante a instalação (escreve ~/.claude_profiles.json). Sem TTY, mantém os atuais.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

PJSON="$HOME/.claude_profiles.json"
command -v jq >/dev/null 2>&1 || { c_warn "jq ausente — rode o 5-claude-code.sh antes."; return 0 2>/dev/null || exit 0; }
[[ -f $PJSON ]] || echo '{}' >"$PJSON"

c_info "Perfis do Claude Code atuais:"
jq -r 'to_entries[] | "   \(.key) → \(.value.WorkDir)"' "$PJSON" 2>/dev/null
[[ $(jq 'length' "$PJSON") -gt 0 ]] || echo "   (nenhum)"

if [[ ! -t 0 || ! -t 1 ]]; then
    c_info "Sem TTY — mantenho os perfis atuais (use 'c add <nome>' depois)."
    return 0 2>/dev/null || exit 0
fi

c_info "Cada perfil tem config/login isolados (CLAUDE_CONFIG_DIR próprio)."
while :; do
    printf '\nNome do perfil a criar/editar (Enter p/ terminar): '
    read -r name
    [[ -n $name ]] || break
    local_lc=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '_')
    printf '  WorkDir [%s/.claude.%s]: ' "$HOME" "$local_lc"
    read -r wd
    [[ -n $wd ]] || wd="$HOME/.claude.$local_lc"
    mkdir -p "$wd"
    tmp=$(mktemp)
    jq --arg n "$name" --arg w "$wd" '.[$n] = {WorkDir:$w, Args:""}' "$PJSON" >"$tmp" && mv "$tmp" "$PJSON"
    # linka o CLAUDE.md global dentro do perfil
    [[ -r $HOME/.claude/CLAUDE.md && ! -e $wd/CLAUDE.md ]] && ln -s "$HOME/.claude/CLAUDE.md" "$wd/CLAUDE.md"
    pkg_status "perfil: $name" "✓ $wd" "$C_GREEN"
    log_entry dev "perfil $name" configured "$wd"
done

c_info "Uso:  c  (escolhe e roda) · c ls · c rm <nome>"
