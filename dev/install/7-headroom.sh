#!/usr/bin/env bash
# 7-headroom.sh — Headroom (compressão de contexto) integrado ao Claude Code.
#
# Headroom NÃO é um plugin de marketplace; é um CLI/wrapper que intercepta as
# requisições do Claude Code e comprime o contexto. `headroom wrap claude` é
# GLOBAL — vale para todas as invocações do claude (logo, todos os perfis).
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# uv para instalar CLIs Python (o Arch bloqueia pip no sistema).
repo_install uv
command -v uv >/dev/null 2>&1 || { c_warn "uv ausente — pulei o headroom."; return 0 2>/dev/null || exit 0; }

# Garante ~/.local/bin no PATH (uv tool instala lá; o wrap cria o shim do claude lá).
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if [[ -f $ZSHRC ]] && ! grep -q 'HOME/.local/bin' "$ZSHRC"; then
    printf '\n# ~/.local/bin no PATH (uv tools, headroom wrap)\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$ZSHRC"
fi
export PATH="$HOME/.local/bin:$PATH"

# Instala o headroom-ai com todos os extras.
if uv tool list 2>/dev/null | grep -qiE '^headroom'; then
    pkg_status "headroom-ai" "= já instalado" "$C_DIM"
    log_entry dev headroom-ai skipped "uv tool"
elif uv tool install "headroom-ai[all]" >/dev/null 2>&1; then
    pkg_status "headroom-ai" "✓ instalado (uv tool)" "$C_GREEN"
    log_entry dev headroom-ai configured "uv tool install headroom-ai[all]"
else
    pkg_status "headroom-ai" "✗ falhou" "$C_RED"
    log_entry dev headroom-ai failed "uv tool install"
    return 0 2>/dev/null || exit 0
fi

# IMPORTANTE: `headroom wrap claude` NÃO é um passo de setup — ele sobe o proxy
# e LANÇA o Claude Code na hora (rodá-lo aqui faz o claude abrir sem stdin e
# falhar). A integração fica na função `c`: ela lança via `headroom wrap claude`
# (com o CLAUDE_CONFIG_DIR do perfil), então TODO perfil roteia pelo Headroom.
c_info "Integração via função 'c' (headroom wrap claude por perfil). Abra um novo shell p/ o PATH valer."
c_info "Testar à mão:  headroom wrap claude     |  diagnóstico:  headroom doctor"
