#!/usr/bin/env bash
# 7-headroom.sh — Headroom (compressão de contexto) integrado ao Claude Code.
#
# Headroom NÃO é um plugin de marketplace; é um CLI que sobe um proxy local e
# comprime o contexto das requisições. A integração fica na função `c`
# (dev/claude/claude.zsh), que chama `headroom wrap claude --1m`.
#
# Por que `wrap` e não ANTHROPIC_BASE_URL: apontar a base URL pra um host
# customizado dispara um gate client-side do Claude Code que desliga a janela de
# 1M tokens (headroom#1158) e o carregamento de tools sob demanda (headroom#746).
# O `wrap` contorna os dois; o roteamento por variável de ambiente, não.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# uv para instalar CLIs Python (o Arch bloqueia pip no sistema).
repo_install uv
command -v uv >/dev/null 2>&1 || { c_warn "uv ausente — pulei o headroom."; return 0 2>/dev/null || exit 0; }

# Garante ~/.local/bin no PATH (uv tool instala lá).
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if [[ -f $ZSHRC ]] && ! grep -q 'HOME/.local/bin' "$ZSHRC"; then
    printf '\n# ~/.local/bin no PATH (uv tools)\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$ZSHRC"
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

# Subir o proxy NÃO é passo de setup — ele fica no ar servindo requisições, então
# rodá-lo aqui travaria a instalação. Quem sobe (e reaproveita) é o `wrap`.
c_info "Integração via função 'c' → headroom wrap claude --1m"
c_info "Diagnóstico:  headroom doctor   |  economia acumulada:  headroom doctor | grep savings"
