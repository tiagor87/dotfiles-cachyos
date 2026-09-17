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
# SELEÇÃO DE MODELO POR AGENTE AUTÔNOMO/SUBAGENT: o env ANTHROPIC_DEFAULT_*_MODEL
# só cobre o tier "default" de cada família (sonnet/opus/haiku) — um agente que
# pede um alias específico (ex. "claude-sonnet-5") por fora do default manda
# esse nome LITERAL pro Bedrock, que rejeita (não aceita model id on-demand, só
# ARN de inference profile). Isso já causou erro real. A correção é o
# `modelOverrides` do settings.json: mapeia qualquer alias conhecido pro ARN
# certo, e junto com `availableModels` + `enforceAvailableModels: true` trava a
# escolha só nos modelos com ARN configurado — nada de um agente escolher algo
# sem tradução possível. `bc` escreve essas quatro chaves (model,
# availableModels, enforceAvailableModels, modelOverrides) no settings.json do
# perfil a cada execução, via jq, preservando o resto do arquivo (os hooks que
# o dev/install/6-ai-memory.sh registrou ali).
#
# Credencial: vem do AWS CLI do ambiente (env, ~/.aws/credentials, SSO). Sem
# AWS_PROFILE setado, e como não existe perfil `default` neste `~/.aws/config`,
# a cadeia de credenciais do SDK não acha nada em local nenhum e cai pro
# fallback de rede (IMDS/ECS) — que numa máquina que não é EC2 FICA TRAVADO
# por vários segundos antes de desistir. Isso já aconteceu e parecia "falha de
# comunicação com a API": não era a API, era a resolução de credencial nunca
# terminando. Por isso o default abaixo, e por isso o preflight com timeout —
# falhar em ~8s com mensagem clara bate de longe ficar pendurado no meio do
# `ai-memory run`.
#
# NÃO usa `awsCredentialExport` (o comando `aws configure export-credentials`
# do settings.json de exemplo): esse mecanismo só roda depois de um trust-check
# do workspace, e não deu pra confirmar se `--yolo` libera isso — arriscava
# trocar uma falha já resolvida (credencial) por outra silenciosa em projeto
# novo ainda não confiado. AWS_PROFILE + o preflight abaixo já é testado e
# cobre o mesmo problema sem essa incerteza.
#
# Pra trocar o perfil: `AWS_PROFILE=bloquo-internal bc` (ou qualquer outro do
# `aws configure list-profiles`).
#
# Uso:
#   bc [args...]              → Claude Code no Bedrock, na pasta atual
#   AWS_PROFILE=... bc        → troca o perfil AWS (default: bloquo-bedrock)
#   AWS_REGION=... bc         → troca a região (sobrepõe o BEDROCK_AWS_REGION)
#   CLAUDE_BEDROCK_DIR=... bc → troca o diretório de config
bc() {
    if ! command -v jq >/dev/null 2>&1; then
        print -u2 "bc: jq ausente — precisa pra escrever o modelOverrides no settings.json."
        return 1
    fi

    local faltando=()
    local v
    for v in BEDROCK_ARN_HAIKU_4_5 BEDROCK_ARN_SONNET_4_6 BEDROCK_ARN_SONNET_5 BEDROCK_ARN_OPUS_4_8 BEDROCK_ARN_OPUS_5; do
        [[ -n ${(P)v} ]] || faltando+=("$v")
    done
    if (( ${#faltando} )); then
        print -u2 "bc: faltam no ~/.zshenv: ${(j:, :)faltando}"
        print -u2 "bc: veja o cabeçalho de ~/.config/claude/claude.zsh para o formato."
        return 1
    fi

    # `local`, não `export`: só vale pra esta invocação. Exportar mudaria o
    # shell interativo pra sempre — todo `aws` digitado depois do `bc` herdaria
    # o bloquo-bedrock sem avisar.
    local AWS_PROFILE="${AWS_PROFILE:-bloquo-bedrock}"

    # Preflight COM TIMEOUT: se a credencial não resolver (perfil errado, SSO
    # expirado, sem rede), falha aqui em segundos — não dentro do claude, onde
    # o sintoma vira um `bc` pendurado sem explicação nenhuma.
    local erro
    if ! erro=$(timeout 8 aws sts get-caller-identity --profile "$AWS_PROFILE" 2>&1 >/dev/null); then
        print -u2 "bc: credencial AWS não resolveu pro perfil '$AWS_PROFILE' (timeout de 8s ou erro):"
        print -u2 "bc:   $erro"
        print -u2 "bc: rode 'aws sso login --profile $AWS_PROFILE' e tente de novo."
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

    # settings.json do perfil: só as 4 chaves de seleção de modelo são
    # OWNED por esta função — sobrescritas por inteiro a cada chamada, pra não
    # sobrar alias órfão se um modelo sair da lista. Tudo o mais no arquivo
    # (hoje, os hooks do ai-memory) passa direto.
    #
    # AS CHAVES TÊM QUE SER O MODEL ID EXATO DO CATÁLOGO DO CLAUDE CODE, não um
    # nome "bonito" qualquer — testado e caiu em DOIS jeitos de quebrar: com
    # "claude-haiku-4-5" (sem a data), o alias não batia com nada no catálogo e
    # a string crua ia pro Bedrock (400 invalid identifier); com o id exato mas
    # de fora do modelOverrides, o Claude Code monta sozinho um cross-region
    # profile genérico do sistema (us.anthropic.<id>) que a role
    # ClaudeCodeBedrock não tem permissão de invocar (403). O Haiku 4.5 é o caso
    # com pegadinha: o id de catálogo carrega a data de release
    # (claude-haiku-4-5-20251001), diferente de sonnet/opus, que não carregam.
    # Se um agente ainda voltar com "modelo inválido" ou 403 depois de uma
    # atualização de modelo, o id abaixo provavelmente mudou de novo.
    local settings="$dir/settings.json"
    local existing='{}'
    [[ -f $settings ]] && existing=$(cat "$settings")
    local novo
    novo=$(jq \
        --arg model "claude-sonnet-4-6" \
        --arg haiku45  "$BEDROCK_ARN_HAIKU_4_5" \
        --arg sonnet46 "$BEDROCK_ARN_SONNET_4_6" \
        --arg sonnet5  "$BEDROCK_ARN_SONNET_5" \
        --arg opus48   "$BEDROCK_ARN_OPUS_4_8" \
        --arg opus5    "$BEDROCK_ARN_OPUS_5" \
        '.model = $model
         | .availableModels = ["claude-haiku-4-5-20251001","claude-sonnet-4-6","claude-sonnet-5","claude-opus-4-8","claude-opus-5"]
         | .enforceAvailableModels = true
         | .modelOverrides = {
             "claude-haiku-4-5-20251001": $haiku45,
             "claude-sonnet-4-6": $sonnet46,
             "claude-sonnet-5": $sonnet5,
             "claude-opus-4-8": $opus48,
             "claude-opus-5": $opus5
           }' <<<"$existing") || {
        print -u2 "bc: jq falhou montando $settings — settings.json existente pode estar com JSON inválido."
        return 1
    }
    print -r -- "$novo" >"$settings"

    CLAUDE_CONFIG_DIR="$dir" \
    CLAUDE_CODE_USE_BEDROCK=1 \
    AWS_PROFILE="$AWS_PROFILE" \
    AWS_REGION="${AWS_REGION:-${BEDROCK_AWS_REGION:-us-east-1}}" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$BEDROCK_ARN_SONNET_4_6" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$BEDROCK_ARN_OPUS_5" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$BEDROCK_ARN_HAIKU_4_5" \
    ANTHROPIC_CUSTOM_HEADERS="$headers" \
        ai-memory run claude --yolo "$@"
}
