#!/usr/bin/env bash
# 14-opencode.sh — OpenCode configurado pro Amazon Bedrock (mesma conta do
# Claude Code em dev/claude/claude.zsh).
#
# opencode.json É VERSIONADO COM PLACEHOLDERS, não com as ARNs literais: este
# repo é público, e o ARN de application-inference-profile carrega o número da
# conta AWS. O `{env:VAR}` é resolvido pelo próprio opencode — substituição no
# texto bruto do JSONC, antes do parse, então funciona em qualquer string
# aninhada (confirmado na fonte: packages/opencode/src/config/config.ts,
# ConfigVariable.substitute). Nada de gerar o arquivo via jq feito o `bc()` em
# dev/claude/claude.zsh: como o opencode já faz a interpolação sozinho, um
# symlink comum já basta — mais simples, e sem precisar rodar nada a cada
# lançamento do `opencode`.
#
# As variáveis (BEDROCK_AWS_REGION, BEDROCK_ARN_*) vêm do ~/.zshenv, exportado
# em todo shell zsh — inclusive o que lança o `opencode`. Sem elas no ambiente,
# o opencode falha ao resolver `{env:...}` (ver aviso no fim deste script).
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# extra/opencode — repo oficial do Arch, sem precisar de AUR.
repo_install opencode

symlink "$HOME/.config/opencode/opencode.json" \
        "$DOTFILES_ROOT/dev/opencode/opencode.json" \
        "opencode.json (provider amazon-bedrock)"

# GREEN check leve: confere que as variáveis que o {env:...} do config espera
# estão de fato no ~/.zshenv — não dá pra validar a resolução em si sem rodar
# o opencode de verdade (e isso pede credencial AWS interativa da primeira
# vez), mas isso aqui já pega o caso mais comum de quebra silenciosa.
faltando=()
for v in BEDROCK_AWS_REGION BEDROCK_ARN_HAIKU_4_5 BEDROCK_ARN_SONNET_4_6 \
         BEDROCK_ARN_SONNET_5 BEDROCK_ARN_OPUS_4_8 BEDROCK_ARN_OPUS_5 \
         BEDROCK_ARN_GROK_4_6 BEDROCK_ARN_DEEPSEEK_R1 BEDROCK_ARN_GPT5_6_TERRA; do
    grep -q "^export $v=" "$HOME/.zshenv" 2>/dev/null || faltando+=("$v")
done
if (( ${#faltando[@]} )); then
    pkg_status "opencode.json vars" "✗ faltam no ~/.zshenv" "$C_RED"
    log_entry dev "opencode.json vars" failed "faltam: ${faltando[*]}"
    c_warn "sem essas variáveis, o opencode falha resolvendo {env:...}: ${faltando[*]}"
else
    pkg_status "opencode.json vars" "✓ todas no ~/.zshenv" "$C_GREEN"
    log_entry dev "opencode.json vars" configured "9 vars conferidas"
fi

c_info "Uso:  opencode                              (modelo default do opencode)"
c_info "      opencode --model amazon-bedrock/claude-sonnet-5"
c_info "      opencode --model amazon-bedrock/cc-grok-4-6"
c_info "Perfil AWS: bloquo-bedrock (mesmo do 'bc' em dev/claude/claude.zsh)"
