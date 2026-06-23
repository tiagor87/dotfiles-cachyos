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

# Wrap global do claude (cobre todos os perfis automaticamente).
if command -v headroom >/dev/null 2>&1; then
    if headroom wrap claude >/dev/null 2>&1; then
        pkg_status "headroom wrap claude" "✓ global (todos os perfis)" "$C_GREEN"
        log_entry dev "headroom wrap" configured "claude (global)"
    else
        pkg_status "headroom wrap claude" "! rode manual: headroom wrap claude" "$C_YELLOW"
        log_entry dev "headroom wrap" failed "headroom wrap claude"
    fi
fi
c_info "Wrap é global: vale para 'c' em qualquer perfil. Abra um novo shell p/ o PATH valer."
