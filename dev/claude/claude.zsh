# claude.zsh — Claude Code rodando através do Headroom.
#
# Config 100% padrão: ~/.claude, sem perfis, sem CLAUDE_CONFIG_DIR.
#
# `headroom wrap claude` é OBRIGATÓRIO — não dá pra trocar por ANTHROPIC_BASE_URL.
# Com a base URL apontando pra um host customizado, o Claude Code aplica um gate
# client-side que desliga:
#   • a janela de contexto de 1M tokens  (headroom#1158 → flag --1m)
#   • o carregamento de tools sob demanda (headroom#746  → o wrap mantém ligado)
#   • o /remote-control (/rc)             (sem contorno possível)
# O wrap sobe/reaproveita o proxy, registra os MCPs (headroom_retrieve +
# tokensave) e instala o hook do rtk sozinho.
#
# CLAUDE_MODEL: o --1m grava ANTHROPIC_MODEL=<opus>[1m], e o <opus> default do
# headroom é uma geração atrás — sem fixar aqui, `c` cai calado num modelo
# velho. Sem o --1m o headroom não toca no modelo, mas a janela fica em 200k:
# os dois andam juntos, não dá pra ter 1M sem fixar. BUMP A CADA GERAÇÃO NOVA.
#
# Flags opt-in do headroom (nenhuma é default — todas são `is_flag` do Click,
# que resolve pra False):
#   --code-graph  indexa o cwd e fica com um watcher reindexando ao vivo. O
#                 índice sob demanda do tokensave já roda sem esta flag (o wrap
#                 chama `tokensave init/sync` no registro do MCP); ela só
#                 acrescenta o watcher. RESSALVA: o help diz "only useful when
#                 the proxy is launched from a project root", e o proxy é
#                 reaproveitado entre invocações — o primeiro `c` fixa o cwd,
#                 então um `c` noutro projeto herda o watcher no diretório
#                 errado.
#   --memory      memória persistente em SQLite, um DB por workspace
#                 (.headroom/memory.db). RESSALVA: sobrepõe às camadas que já
#                 existem — ~/.claude/projects/<proj>/memory/ e o
#                 tokensave_session_recall. Se as três divergirem, não há
#                 precedência definida entre elas.
#   --learn       aprende padrões do tráfego ao vivo e grava no MEMORY.md.
#
# ATENÇÃO: o setup do wrap acrescenta `@RTK.md` ao ~/.claude/CLAUDE.md, que é
# symlink pro repo — ou seja, ele escreve no arquivo VERSIONADO. Se aparecer um
# diff sozinho em dev/claude/CLAUDE.md, foi isto. Não adianta remover a linha:
# o próximo `c` a recoloca.
#
# Uso:
#   c [args...]         → Claude Code na pasta atual, via Headroom, janela de 1M
#   CLAUDE_MODEL=... c  → força outro modelo
#
# Pra rodar sem o Headroom, use o `claude` direto — esta função não tem desvio.

: ${CLAUDE_MODEL:=claude-opus-5}

c() {
    # Nada de mexer em ANTHROPIC_BASE_URL: quem define o roteamento é o wrap, e
    # ele sobrescreve o que vier herdado. Rodando `c` de dentro de uma sessão já
    # roteada (inclusive apontando pra um proxy morto), o wrap ignora a var
    # herdada, sobe o proxy dele e reescreve — verificado.
    #
    # `--` separa as flags do headroom das do claude (documentado em
    # `headroom wrap claude --help`). Cold start do proxy carrega modelos de ML
    # e pode levar dezenas de segundos na primeira invocação.
    ANTHROPIC_MODEL="$CLAUDE_MODEL" \
        headroom wrap claude --1m --code-graph --memory --learn \
        -- --dangerously-skip-permissions "$@"
}
