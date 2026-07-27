# claude.zsh — Claude Code rodando através do Headroom.
#
# `headroom wrap claude` é OBRIGATÓRIO — não dá pra trocar por ANTHROPIC_BASE_URL.
# Com a base URL apontando pra um host customizado, o Claude Code aplica um gate
# client-side que desliga:
#   • a janela de contexto de 1M tokens  (headroom#1158 → flag --1m)
#   • o carregamento de tools sob demanda (headroom#746  → flag --tool-search)
#   • o /remote-control (/rc)             (sem contorno possível)
# O wrap sobe/reaproveita o proxy, injeta o beta de 1M e registra os MCPs
# (headroom_retrieve + tokensave) sozinho.
#
# Deixamos o wrap fazer o "context-tool setup": ele embarca o binário do rtk em
# ~/.headroom/bin/, symlinka em ~/.local/bin/ e registra o hook PreToolUse. O rtk
# filtra a saída dos comandos ANTES dela virar request — camada que o Headroom
# não alcança, já que a compressão dele para no `prefix_frozen` pra não
# invalidar o prefixo do prompt cache. Não instale `rtk-bin` do AUR: viraria um
# segundo binário disputando o PATH com o do headroom.
#
# ATENÇÃO: esse setup também acrescenta `@RTK.md` ao ~/.claude/CLAUDE.md, que é
# symlink pro repo — ou seja, ele escreve no arquivo VERSIONADO. Se aparecer um
# diff sozinho em dev/claude/CLAUDE.md, foi isto. Não adianta remover a linha:
# o próximo `c` a recoloca.
#
# CLAUDE_MODEL: o --1m grava ANTHROPIC_MODEL=<opus>[1m], e o <opus> default do
# headroom é o opus-4-8 — sem fixar aqui, `c` cai calado num modelo antigo. O
# headroom respeita um ANTHROPIC_MODEL já setado (só acrescenta o [1m]).
# BUMP AQUI a cada geração nova de modelo.
#
# Uso:
#   c [args...]      → Claude Code na pasta atual, via Headroom, janela de 1M
#   c --no-hr [...]  → sem Headroom (direto na API)
#   CLAUDE_MODEL=... c   → força outro modelo

: ${CLAUDE_MODEL:=claude-opus-5}

c() {
    local -a claude_args
    claude_args=(--dangerously-skip-permissions)

    # `env -u` é obrigatório nos dois caminhos: rodando `c` de DENTRO de uma
    # sessão do Claude, estas vars já vêm exportadas apontando pro proxy do
    # processo pai. Herdá-las empilharia proxy sobre proxy (ou apontaria pra um
    # proxy morto) em vez de deixar o wrap definir o roteamento.
    local -a clean_env
    clean_env=(env -u ANTHROPIC_BASE_URL -u OPENAI_BASE_URL -u HEADROOM_PROXY_URL
               "ANTHROPIC_MODEL=$CLAUDE_MODEL")

    if [[ ${1:-} == --no-hr ]]; then
        shift
        "${clean_env[@]}" claude "${claude_args[@]}" "$@"
        return
    fi

    if ! command -v headroom >/dev/null 2>&1; then
        print -P "%F{yellow}! headroom ausente — seguindo direto na API%f"
        "${clean_env[@]}" claude "${claude_args[@]}" "$@"
        return
    fi

    # `--` separa as flags do headroom das do claude (documentado em
    # `headroom wrap claude --help`). Cold start do proxy carrega modelos de ML
    # e pode levar dezenas de segundos na primeira invocação.
    "${clean_env[@]}" headroom wrap claude --1m -- "${claude_args[@]}" "$@"
}
