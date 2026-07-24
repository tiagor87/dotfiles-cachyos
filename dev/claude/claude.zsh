# claude.zsh — Claude Code com perfis isolados (porte do claude.ps1 do dotfiles-windows)
#
# Cada perfil tem um CLAUDE_CONFIG_DIR próprio (config + login isolados) e uma
# porta de proxy Headroom própria, mapeados em ~/.claude_profiles.json:
#   { "Nome": { "WorkDir": "...", "Args": "...", "Port": 8787 } }.
#
# O Headroom entra por ANTHROPIC_BASE_URL / OPENAI_BASE_URL apontando pro proxy
# (reaproveitado se já estiver rodando), não mais por `headroom wrap claude`.
#
# Uso:
#   c                 → seletor (fzf) e roda o Claude Code na pasta atual
#   c <perfil>        → roda direto nesse perfil
#   c ls              → lista os perfis
#   c add <nome> [workdir]   → cria/edita um perfil
#   c rm  <nome>      → remove um perfil

_CLAUDE_PROFILES="$HOME/.claude_profiles.json"

# _headroom_ensure_proxy <porta> — garante um proxy Headroom de pé nessa porta.
#
# Substitui o `headroom wrap`: em vez de o wrap subir um proxy por processo
# lançado, reaproveitamos um já rodando (o proxy é compartilhável e atende
# Anthropic e OpenAI na mesma porta) e roteamos por variável de ambiente.
# /livez é o health check do proxy (mesmo endpoint que o codex-fugu usa).
_headroom_ensure_proxy() {
    local port="$1" i
    curl -fsS --max-time 1 "http://127.0.0.1:$port/livez" >/dev/null 2>&1 && return 0
    print -P "%F{8}⏳ subindo o proxy Headroom em :$port...%f"
    headroom proxy -p "$port" >"/tmp/headroom-proxy-$port.log" 2>&1 &
    disown
    # Cold start pode carregar modelos de ML — o próprio `wrap` espera até 45 s.
    for i in {1..60}; do
        curl -fsS --max-time 1 "http://127.0.0.1:$port/livez" >/dev/null 2>&1 && return 0
        sleep 0.5
    done
    print -P "%F{red}proxy não respondeu em 30s — veja /tmp/headroom-proxy-$port.log%f"
    return 1
}

c() {
    command -v jq >/dev/null 2>&1 || { print -P "%F{red}jq não instalado%f"; return 1; }
    [[ -f $_CLAUDE_PROFILES ]] || echo '{}' >"$_CLAUDE_PROFILES"

    local sub="${1:-}"
    case "$sub" in
        ls|list)
            jq -r 'to_entries[] | "  \(.key)\t→ \(.value.WorkDir)\t:\(.value.Port // "auto")"' "$_CLAUDE_PROFILES"
            return ;;
        add)
            local name="${2:?uso: c add <nome> [workdir]}"
            local wd="${3:-$HOME/.claude.${name:l}}"
            mkdir -p "$wd"
            # Porta de proxy própria: pega a maior porta já usada + 1 (base 8787),
            # garantindo que dois perfis nunca colidam ao rodar em paralelo.
            local port; port=$(jq -r '[.[].Port // 0] | max // 0' "$_CLAUDE_PROFILES")
            [[ $port -ge 8787 ]] && port=$((port+1)) || port=8787
            local tmp; tmp=$(mktemp)
            jq --arg n "$name" --arg w "$wd" --argjson p "$port" '.[$n] = {WorkDir:$w, Args:"", Port:$p}' "$_CLAUDE_PROFILES" >"$tmp" && mv "$tmp" "$_CLAUDE_PROFILES"
            # linka o CLAUDE.md global dentro do WorkDir do perfil
            [[ -r $HOME/.claude/CLAUDE.md && ! -e $wd/CLAUDE.md ]] && ln -s "$HOME/.claude/CLAUDE.md" "$wd/CLAUDE.md"
            print -P "%F{green}✓ perfil '$name' → $wd  (porta $port)%f"
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

    local wd args port
    wd=$(jq -r --arg n "$sel" '.[$n].WorkDir // ""' "$_CLAUDE_PROFILES")
    args=$(jq -r --arg n "$sel" '.[$n].Args // ""' "$_CLAUDE_PROFILES")
    port=$(jq -r --arg n "$sel" '.[$n].Port // ""' "$_CLAUDE_PROFILES")
    [[ -n $wd ]] || wd="$HOME/.claude.${sel:l}"
    # Perfis antigos (sem Port no JSON): deriva uma porta estável do nome,
    # no intervalo 8787..9786, para não colidir com outros perfis.
    [[ -n $port ]] || port=$(( 8787 + $(printf '%s' "$sel" | cksum | awk '{print $1}') % 1000 ))
    mkdir -p "$wd"

    # HONCHO_WORKSPACE_ID em PascalCase (compat. com o fluxo do dotfiles-windows)
    local wsid; wsid=$(printf '%s' "$sel" | sed -E 's/[ _-]+/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' | tr -d ' ')

    print -P "\n%F{cyan}### ${sel:u} ENVIRONMENT ###%f"
    print -P "%F{cyan}📌 Perfil:%f $sel   %F{8}⚙ CLAUDE_CONFIG_DIR=$wd  🔌 proxy :$port%f\n"

    # Roteamento pelo Headroom via variável de ambiente (não mais `headroom wrap`):
    # garantimos o proxy de pé na porta DESTE perfil e apontamos as base URLs pra
    # ele. Cada perfil tem sua porta, então rodam em paralelo sem colisão.
    # CLAUDE_CONFIG_DIR isola config/login por perfil. --dangerously-skip-permissions
    # é sempre passado ao claude.
    # HEADROOM_PROXY_URL fixa a MESMA porta no proxy e no registro do MCP
    # headroom_retrieve — se não bater, o retrieve não consegue expandir nada.
    if command -v headroom >/dev/null 2>&1; then
        local hr_url="http://127.0.0.1:$port"
        # Casa a porta do MCP headroom_retrieve com a do proxy DESTE perfil.
        # O registro fica gravado em $wd/.claude.json com env vazio por padrão;
        # `mcp install --force` reescreve env={HEADROOM_PROXY_URL=:$port} só
        # neste CLAUDE_CONFIG_DIR (a config global não é tocada).
        CLAUDE_CONFIG_DIR="$wd" headroom mcp install --agent claude \
            --proxy-url "$hr_url" --force >/dev/null 2>&1
        if _headroom_ensure_proxy "$port"; then
            # ANTHROPIC_BASE_URL vai SEM /v1; OPENAI_BASE_URL COM /v1 (formato
            # documentado em `headroom proxy --help`). O OPENAI_BASE_URL é
            # exportado porque o Claude chama o codex em subprocesso — assim a
            # sessão do codex também passa pelo proxy.
            # ENABLE_TOOL_SEARCH é OBRIGATÓRIO: com ANTHROPIC_BASE_URL apontando
            # pra host customizado e essa var vazia, o Claude Code desliga o
            # carregamento de tools sob demanda e infla o contexto em dezenas de
            # K tokens (headroom/cli/wrap.py:204) — anularia o ganho do proxy.
            CLAUDE_CONFIG_DIR="$wd" HONCHO_WORKSPACE_ID="$wsid" \
            HEADROOM_PROXY_URL="$hr_url" \
            ANTHROPIC_BASE_URL="$hr_url" \
            OPENAI_BASE_URL="$hr_url/v1" \
            ENABLE_TOOL_SEARCH="${ENABLE_TOOL_SEARCH:-true}" \
                claude --dangerously-skip-permissions ${=args}
            return
        fi
        # Proxy não subiu: melhor rodar sem compressão do que apontar o Claude
        # pra um endpoint morto.
        print -P "%F{yellow}! seguindo sem Headroom (proxy indisponível)%f"
    fi
    # `env -u` é obrigatório aqui: rodando `c` de DENTRO de uma sessão do Claude,
    # estas vars já vêm exportadas apontando pro proxy do processo pai. Herdá-las
    # mandaria o novo Claude pra um proxy alheio (ou morto) em vez de ir direto
    # na API — o oposto do fallback.
    env -u ANTHROPIC_BASE_URL -u OPENAI_BASE_URL -u HEADROOM_PROXY_URL \
        CLAUDE_CONFIG_DIR="$wd" HONCHO_WORKSPACE_ID="$wsid" \
        claude --dangerously-skip-permissions ${=args}
}
