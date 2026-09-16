# claude.zsh — as funções que sobem o Claude Code: `c` (conta Anthropic) e
# `bc` (Amazon Bedrock).
#
# `c` roda na config 100% padrão: ~/.claude, sem perfis, sem CLAUDE_CONFIG_DIR.
# `bc` é o único desvio disso, e usa ~/.claude-bedrock (ver o bloco lá embaixo).
#
# As duas lançam o Claude Code através do `ai-memory run`, que abre um
# workstream gerenciado: os hooks de sessão gravam as observações e o MCP
# `ai-memory` devolve essa memória pro agente. O `--yolo` é flag DO WRAPPER
# (vira `--dangerously-skip-permissions` no claude), não do claude — o resto
# dos NATIVE_ARGS o ai-memory repassa byte a byte, na ordem.
#
# O `ai-memory` vem do dev/install/6-ai-memory.sh, que também registra o MCP e
# os hooks nos DOIS perfis (~/.claude e ~/.claude-bedrock). Sem o binário no
# PATH as duas funções morrem em "command not found" — pra rodar sem wrapper
# nenhum, use o `claude` direto.
#
# HISTÓRICO — até o commit 8e56f05 o `c` era `headroom wrap claude --rtk --1m
# --code-graph --memory --learn`. Quem lê este arquivo esperando o Headroom
# precisa saber o que saiu junto com ele:
#   • a janela de 1M vinha do `--1m`, que gravava ANTHROPIC_MODEL=<opus>[1m] —
#     por isso o CLAUDE_MODEL fixo aqui. Hoje a janela se escolhe no /model
#     (ou em ANTHROPIC_MODEL no ambiente), e a variável não tinha mais leitor.
#   • o hook PreToolUse do rtk e o ~/.claude/RTK.md eram instalados pelo wrap,
#     e só com `--rtk`. Sem o wrap não existem mais — conferido: o
#     ~/.claude/settings.json não tem `hooks` e o RTK.md não está lá. A saída
#     do Bash não é mais filtrada.
#   • o wrap também acrescentava `@RTK.md` ao ~/.claude/CLAUDE.md, que é
#     symlink pro repo — aquele diff que aparecia sozinho em
#     dev/claude/CLAUDE.md não volta mais.
# O Headroom continua instalado (dev/install/7-headroom.sh) e em uso, mas pelo
# `codex` (dev/codex/codex.zsh), não pelo Claude Code.
#
# Uso:
#   c   → Claude Code na pasta atual, em YOLO, no workstream do ai-memory
#   bc  → idem, no Bedrock (ver o bloco abaixo)
#
# RESSALVA: o `c` não repassa `"$@"` — `c --resume` e afins são engolidos em
# silêncio. Está assim desde o 8e56f05, de propósito; o `bc` repassa.

c() {
    ai-memory run claude --yolo
}

# ---------------------------------------------------------------------------
# bc — Claude Code no Amazon Bedrock, config isolada em ~/.claude-bedrock.
#
# Por que um CLAUDE_CONFIG_DIR separado: a config padrão (~/.claude) guarda a
# credencial da Anthropic, os MCPs e o histórico da conta pessoal. Apontar o
# mesmo diretório pro Bedrock mistura sessões de dois backends no mesmo
# projects/ e faz o onboarding/login brigar com o CLAUDE_CODE_USE_BEDROCK.
# Com o diretório próprio, `c` e `bc` convivem sem se pisar — cada um com seu
# settings.json, seus MCPs e seu histórico.
#
# OS IDENTIFICADORES NÃO MORAM AQUI. Este repo é público, e o ARN do inference
# profile carrega o número da conta AWS. Eles vêm do ~/.zshenv, que não é
# versionado (mesma convenção do resto dos segredos — ver o .gitignore):
#
#   export BEDROCK_SONNET_ARN="arn:aws:bedrock:<região>:<conta>:application-inference-profile/<id>"
#   export BEDROCK_OPUS_ARN="arn:aws:bedrock:<região>:<conta>:application-inference-profile/<id>"
#   export BEDROCK_HAIKU_ARN="arn:aws:bedrock:<região>:<conta>:application-inference-profile/<id>"
#   export BEDROCK_GUARDRAIL_ID="<id>"        # opcional (com o VERSION, liga o guardrail)
#   export BEDROCK_GUARDRAIL_VERSION="<n>"    # opcional
#   export BEDROCK_AWS_REGION="us-east-1"     # opcional (default us-east-1)
#
# Por que nomes BEDROCK_* e não os ANTHROPIC_DEFAULT_*_MODEL direto: o ~/.zshenv
# exporta pra TODO shell, e o Claude Code lê os ANTHROPIC_DEFAULT_* mesmo fora
# do Bedrock — um ARN ali dentro quebraria o `c`. A tradução acontece aqui, no
# escopo de uma invocação só.
#
# São application-inference-profiles (ARN completo, não model id): é o que
# carrega o guardrail e o tagging de custo do perfil. O guardrail vai em
# ANTHROPIC_CUSTOM_HEADERS, que aceita vários headers separados por \n — daí o
# $'...' do zsh, que é a única forma de a quebra de linha chegar real.
#
# Credencial: vem do AWS CLI do ambiente (env, ~/.aws/credentials, SSO).
# Pra escolher o perfil: `AWS_PROFILE=bloquo bc`.
#
# Uso:
#   bc [args...]              → Claude Code no Bedrock, na pasta atual
#   AWS_PROFILE=... bc        → troca o perfil AWS
#   AWS_REGION=... bc         → troca a região (sobrepõe o BEDROCK_AWS_REGION)
#   CLAUDE_BEDROCK_DIR=... bc → troca o diretório de config
bc() {
    local faltando=()
    local v
    for v in BEDROCK_SONNET_ARN BEDROCK_OPUS_ARN BEDROCK_HAIKU_ARN; do
        [[ -n ${(P)v} ]] || faltando+=("$v")
    done
    if (( ${#faltando} )); then
        print -u2 "bc: faltam no ~/.zshenv: ${(j:, :)faltando}"
        print -u2 "bc: veja o cabeçalho de ~/.config/claude/claude.zsh para o formato."
        return 1
    fi

    local dir="${CLAUDE_BEDROCK_DIR:-$HOME/.claude-bedrock}"
    [[ -d $dir ]] || mkdir -p "$dir"

    # Guardrail é opt-in: sem os dois valores, roda sem header nenhum em vez de
    # mandar um header pela metade (o Bedrock recusa a request se só um for).
    local headers=''
    if [[ -n $BEDROCK_GUARDRAIL_ID && -n $BEDROCK_GUARDRAIL_VERSION ]]; then
        headers="X-Amzn-Bedrock-GuardrailIdentifier: ${BEDROCK_GUARDRAIL_ID}"$'\n'"X-Amzn-Bedrock-GuardrailVersion: ${BEDROCK_GUARDRAIL_VERSION}"
    fi

    CLAUDE_CONFIG_DIR="$dir" \
    CLAUDE_CODE_USE_BEDROCK=1 \
    AWS_REGION="${AWS_REGION:-${BEDROCK_AWS_REGION:-us-east-1}}" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$BEDROCK_SONNET_ARN" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$BEDROCK_OPUS_ARN" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$BEDROCK_HAIKU_ARN" \
    ANTHROPIC_CUSTOM_HEADERS="$headers" \
        ai-memory run claude --yolo "$@"
}
