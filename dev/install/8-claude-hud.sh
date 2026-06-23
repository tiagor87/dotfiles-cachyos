#!/usr/bin/env bash
# 8-claude-hud.sh — Instala o claude-hud (HUD na statusline) em TODOS os perfis.
#
# claude-hud (https://github.com/jarrodwatts/claude-hud) é um plugin de
# marketplace do Claude Code que mostra uso de contexto, tools, agents e todos
# abaixo do input, via a API nativa de statusLine. Como cada perfil tem seu
# CLAUDE_CONFIG_DIR próprio, o plugin é instalado e a statusLine configurada
# uma vez por perfil, lendo ~/.claude_profiles.json. Idempotente.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

REPO="jarrodwatts/claude-hud"
PJSON="$HOME/.claude_profiles.json"

command -v claude >/dev/null 2>&1 || { c_warn "claude ausente — rode o 5-claude-code.sh antes."; return 0 2>/dev/null || exit 0; }
command -v jq     >/dev/null 2>&1 || { c_warn "jq ausente — pulei o claude-hud."; return 0 2>/dev/null || exit 0; }

# Runtime da statusLine: bun (preferido, roda src/index.ts) ou node (dist/index.js).
RUNTIME="$(command -v bun 2>/dev/null || command -v node 2>/dev/null)"
if [[ -z $RUNTIME ]]; then
    pkg_status "claude-hud" "✗ sem bun/node (runtime da statusLine)" "$C_RED"
    log_entry dev claude-hud failed "instale bun ou node (rode o 4-runtimes.sh)"
    return 0 2>/dev/null || exit 0
fi
if [[ $RUNTIME == *bun ]]; then SRC="src/index.ts"; RUNFLAGS=" --env-file /dev/null"; else SRC="dist/index.js"; RUNFLAGS=""; fi

# Comando da statusLine — IDÊNTICO p/ todos os perfis: usa CLAUDE_CONFIG_DIR em
# runtime e resolve dinamicamente a versão mais recente do cache do plugin
# (logo, updates do plugin valem sem re-rodar este script). Exporta COLUMNS p/
# o HUD saber a largura real do terminal (-4 = padding do input do Claude Code).
# Template literal (heredoc com delimitador entre aspas) + substituição dos
# tokens — evita o inferno de escapar as aspas aninhadas do awk/grep.
STATUSLINE_TMPL=$(cat <<'TMPL'
bash -c 'cols=${COLUMNS:-}; case "$cols" in ""|*[!0-9]*) cols=$(stty size </dev/tty 2>/dev/null | awk '"'"'{print $2}'"'"');; esac; case "$cols" in ""|*[!0-9]*) cols=120;; esac; export COLUMNS=$(( cols > 4 ? cols - 4 : 1 )); plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ '"'"'{ print $(NF-1) "\t" $(0) }'"'"' | grep -E '"'"'^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]'"'"' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec "__RUNTIME__"__RUNFLAGS__ "${plugin_dir}__SRC__"'
TMPL
)
STATUSLINE_CMD=${STATUSLINE_TMPL//__RUNTIME__/$RUNTIME}
STATUSLINE_CMD=${STATUSLINE_CMD//__RUNFLAGS__/$RUNFLAGS}
STATUSLINE_CMD=${STATUSLINE_CMD//__SRC__/$SRC}

# Descobre os perfis (WorkDir = CLAUDE_CONFIG_DIR). Sem perfis, usa ~/.claude.
mapfile -t WORKDIRS < <(jq -r '.[].WorkDir // empty' "$PJSON" 2>/dev/null)
[[ ${#WORKDIRS[@]} -gt 0 ]] || WORKDIRS=("$HOME/.claude")

# TMPDIR no mesmo filesystem do $HOME evita 'EXDEV: cross-device link not
# permitted' na instalação do plugin quando /tmp está noutro FS (comum no Linux).
export TMPDIR="$HOME/.cache/tmp"; mkdir -p "$TMPDIR"

for wd in "${WORKDIRS[@]}"; do
    name=$(jq -r --arg w "$wd" 'to_entries[] | select(.value.WorkDir==$w) | .key' "$PJSON" 2>/dev/null | head -1)
    name=${name:-$(basename "$wd")}
    mkdir -p "$wd"

    # 1) Plugin: marketplace add (idempotente) + install só se ainda não houver.
    CLAUDE_CONFIG_DIR="$wd" claude plugin marketplace add "$REPO" >/dev/null 2>&1
    reg="$wd/plugins/installed_plugins.json"
    if [[ -f $reg ]] && jq -e '(.plugins // {}) | keys[] | select(startswith("claude-hud"))' "$reg" >/dev/null 2>&1; then
        pkg_status "claude-hud [$name]" "= plugin já instalado" "$C_DIM"
        log_entry dev "claude-hud/$name" skipped "$wd"
    elif CLAUDE_CONFIG_DIR="$wd" claude plugin install claude-hud >/dev/null 2>&1; then
        pkg_status "claude-hud [$name]" "✓ plugin instalado" "$C_GREEN"
        log_entry dev "claude-hud/$name" installed "$wd"
    else
        pkg_status "claude-hud [$name]" "✗ plugin install falhou" "$C_RED"
        log_entry dev "claude-hud/$name" failed "claude plugin install ($wd)"
        continue
    fi

    # 2) statusLine no settings.json do perfil (merge preservando o resto).
    settings="$wd/settings.json"
    [[ -f $settings ]] || echo '{}' >"$settings"
    if ! jq -e . "$settings" >/dev/null 2>&1; then
        pkg_status "statusLine [$name]" "✗ settings.json inválido — não toquei" "$C_RED"
        log_entry dev "claude-hud/$name statusLine" failed "JSON inválido: $settings"
        continue
    fi
    if jq -e '(.statusLine.command // "") | contains("claude-hud")' "$settings" >/dev/null 2>&1; then
        pkg_status "statusLine [$name]" "= já é claude-hud" "$C_DIM"
        log_entry dev "claude-hud/$name statusLine" skipped "$settings"
    else
        cp "$settings" "$settings.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
        tmp=$(mktemp)
        if jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {type:"command", command:$cmd}' "$settings" >"$tmp" && mv "$tmp" "$settings"; then
            pkg_status "statusLine [$name]" "⚙ configurada (HUD)" "$C_CYAN"
            log_entry dev "claude-hud/$name statusLine" configured "$settings"
        else
            rm -f "$tmp"
            pkg_status "statusLine [$name]" "✗ falhou ao gravar" "$C_RED"
            log_entry dev "claude-hud/$name statusLine" failed "jq merge ($settings)"
        fi
    fi
done

c_info "HUD ativa só em sessões NOVAS — abra um perfil com 'c <perfil>' p/ ver."
c_info "Ajustar extras (tools/agents/todos):  /claude-hud:configure  dentro do Claude."
