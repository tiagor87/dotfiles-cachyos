# claude.zsh — Claude Code com perfis isolados (porte do claude.ps1 do dotfiles-windows)
#
# Cada perfil tem um CLAUDE_CONFIG_DIR próprio (config + login isolados), mapeado
# em ~/.claude_profiles.json: { "Nome": { "WorkDir": "...", "Args": "..." } }.
#
# Uso:
#   c                 → seletor (fzf) e roda o Claude Code na pasta atual
#   c <perfil>        → roda direto nesse perfil
#   c ls              → lista os perfis
#   c add <nome> [workdir]   → cria/edita um perfil
#   c rm  <nome>      → remove um perfil

_CLAUDE_PROFILES="$HOME/.claude_profiles.json"

c() {
    command -v jq >/dev/null 2>&1 || { print -P "%F{red}jq não instalado%f"; return 1; }
    [[ -f $_CLAUDE_PROFILES ]] || echo '{}' >"$_CLAUDE_PROFILES"

    local sub="${1:-}"
    case "$sub" in
        ls|list)
            jq -r 'to_entries[] | "  \(.key)\t→ \(.value.WorkDir)"' "$_CLAUDE_PROFILES"
            return ;;
        add)
            local name="${2:?uso: c add <nome> [workdir]}"
            local wd="${3:-$HOME/.claude.${name:l}}"
            mkdir -p "$wd"
            local tmp; tmp=$(mktemp)
            jq --arg n "$name" --arg w "$wd" '.[$n] = {WorkDir:$w, Args:""}' "$_CLAUDE_PROFILES" >"$tmp" && mv "$tmp" "$_CLAUDE_PROFILES"
            # linka o CLAUDE.md global dentro do WorkDir do perfil
            [[ -r $HOME/.claude/CLAUDE.md && ! -e $wd/CLAUDE.md ]] && ln -s "$HOME/.claude/CLAUDE.md" "$wd/CLAUDE.md"
            print -P "%F{green}✓ perfil '$name' → $wd%f"
            return ;;
        rm|remove)
            local name="${2:?uso: c rm <nome>}"
            local tmp; tmp=$(mktemp)
            jq --arg n "$name" 'del(.[$n])' "$_CLAUDE_PROFILES" >"$tmp" && mv "$tmp" "$_CLAUDE_PROFILES"
            print -P "%F{yellow}perfil '$name' removido (a pasta de config NÃO foi apagada)%f"
            return ;;
    esac

    local -a names; names=(${(f)"$(jq -r 'keys[]' "$_CLAUDE_PROFILES")"})
    [[ ${#names} -gt 0 ]] || { print -P "%F{red}Nenhum perfil. Use: c add <nome>%f"; return 1; }

    local sel="$sub"
    if [[ -z $sel ]]; then
        if command -v fzf >/dev/null 2>&1; then
            sel=$(printf '%s\n' $names | fzf --reverse --height=40% --prompt="Perfil Claude > ")
        else
            local i=1; for n in $names; do print "  [$i] $n"; ((i++)); done
            printf 'Número: '; local idx; read idx; sel=${names[$idx]}
        fi
    fi
    [[ -n $sel ]] || return 1
    jq -e --arg n "$sel" 'has($n)' "$_CLAUDE_PROFILES" >/dev/null 2>&1 || { print -P "%F{red}perfil '$sel' não existe%f"; return 1; }

    local wd args
    wd=$(jq -r --arg n "$sel" '.[$n].WorkDir // ""' "$_CLAUDE_PROFILES")
    args=$(jq -r --arg n "$sel" '.[$n].Args // ""' "$_CLAUDE_PROFILES")
    [[ -n $wd ]] || wd="$HOME/.claude.${sel:l}"
    mkdir -p "$wd"

    # HONCHO_WORKSPACE_ID em PascalCase (compat. com o fluxo do dotfiles-windows)
    local wsid; wsid=$(printf '%s' "$sel" | sed -E 's/[ _-]+/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' | tr -d ' ')

    print -P "\n%F{cyan}### ${sel:u} ENVIRONMENT ###%f"
    print -P "%F{cyan}📌 Perfil:%f $sel   %F{8}⚙ CLAUDE_CONFIG_DIR=$wd%f\n"

    CLAUDE_CONFIG_DIR="$wd" HONCHO_WORKSPACE_ID="$wsid" claude ${=args}
}
