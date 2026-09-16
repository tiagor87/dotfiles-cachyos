#!/usr/bin/env bash
# 6-ai-memory.sh — ai-memory (memória de longo prazo dos agentes) + fiação no Claude Code.
#
# O `ai-memory` é servidor MCP + hooks de ciclo de vida: os hooks gravam
# observações sanitizadas enquanto a sessão roda, e o MCP devolve essa memória
# pro agente na sessão seguinte. É dependência DURA das funções `c` e `bc`
# (dev/claude/claude.zsh), que lançam o claude como `ai-memory run claude
# --yolo` — sem o binário no PATH as duas morrem em "command not found".
#
# POR QUE O NÚMERO 6: o `sort -V` do setup.sh manda, e este script precisa
# rodar DEPOIS do 5-claude-code.sh. O "setup limpo" de lá zera o
# ~/.claude/settings.json, que é exatamente o arquivo onde o `install-hooks`
# escreve — invertida a ordem, a limpeza apaga os hooks recém-instalados.
#
# ai-memory-bin vs ai-memory: os dois são do próprio autor do projeto
# (akitaonrails). O `-bin` traz o binário pré-compilado das releases e declara
# `provides: ai-memory`; o outro compila do fonte em Rust — build longo, sem
# ganho aqui. Ambos instalam /usr/bin/ai-memory, os hooks em
# /usr/share/ai-memory/hooks/ e as units systemd (system e user).
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# jq é usado no GREEN check lá embaixo; o 5-claude-code.sh já o instala, mas
# repetir aqui mantém este script rodável sozinho (`--needed`, então é no-op).
repo_install jq

aur_install ai-memory-bin

# Sem binário não há o que configurar — o aur_install já reportou a falha.
if ! command -v ai-memory >/dev/null 2>&1; then
    c_warn "ai-memory ausente — pulei init, serviço e fiação no Claude Code."
    return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------
# Data dir + config
# ---------------------------------------------------------------------------
# Instalação de usuário (não a de sistema): os dados ficam em
# ~/.local/share/ai-memory e o config em ~/.config/ai-memory/config.toml — os
# mesmos caminhos que a unit de usuário empacotada usa no ExecStart. A de
# sistema usaria /var/lib/ai-memory e /etc/ai-memory/.
AIM_DATA="$HOME/.local/share/ai-memory"
AIM_CONF="$HOME/.config/ai-memory/config.toml"
mkdir -p "$AIM_DATA" "$(dirname "$AIM_CONF")"

# `init` sem --force NÃO sobrescreve o config.toml existente: roda limpo em
# máquina nova e é no-op silencioso na re-execução (exit 0 nos dois casos).
# Por isso não há guarda de "se já existe" aqui — a guarda é do próprio comando.
if ai-memory --data-dir "$AIM_DATA" --config "$AIM_CONF" init >/dev/null 2>&1; then
    pkg_status "ai-memory init" "✓ data dir + config" "$C_GREEN"
    log_entry dev "ai-memory init" configured "$AIM_DATA"
else
    pkg_status "ai-memory init" "✗ falhou" "$C_RED"
    log_entry dev "ai-memory init" failed "init em $AIM_DATA"
fi

# O servidor precisa estar no ar pros hooks terem pra onde POSTar. Loopback
# (127.0.0.1:49374), nada exposto pra fora da máquina.
enable_user_service ai-memory.service

# ---------------------------------------------------------------------------
# Fiação no Claude Code — os DOIS perfis
# ---------------------------------------------------------------------------
# `install-mcp` escreve o servidor MCP em <config-dir>/.claude.json e
# `install-hooks` os 9 eventos de ciclo de vida em <config-dir>/settings.json.
# Os dois respeitam CLAUDE_CONFIG_DIR (verificado), então o mesmo par de
# comandos serve o perfil padrão (`c` → ~/.claude) e o do Bedrock (`bc` →
# ~/.claude-bedrock). Sem esta segunda passada o `bc` roda sem memória nenhuma.
#
# Ambos são idempotentes: substituem só as entradas `ai-memory`, preservam o
# resto do arquivo e deixam um backup datado ao lado antes de cada escrita.
wire_claude_profile() {
    local label="$1" dir="$2" ok=1
    mkdir -p "$dir"
    CLAUDE_CONFIG_DIR="$dir" ai-memory install-mcp   --client claude-code --apply >/dev/null 2>&1 || ok=0
    CLAUDE_CONFIG_DIR="$dir" ai-memory install-hooks --agent  claude-code --apply >/dev/null 2>&1 || ok=0

    # GREEN check: o servidor MCP e os hooks têm que estar NO ARQUIVO.
    if [[ $ok -eq 1 ]] \
        && jq -e '.mcpServers["ai-memory"]' "$dir/.claude.json" >/dev/null 2>&1 \
        && jq -e '.hooks.SessionStart' "$dir/settings.json" >/dev/null 2>&1; then
        pkg_status "ai-memory → $label" "✓ MCP + hooks" "$C_GREEN"
        log_entry dev "ai-memory $label" configured "install-mcp + install-hooks em $dir"
    else
        pkg_status "ai-memory → $label" "✗ falhou" "$C_RED"
        log_entry dev "ai-memory $label" failed "install-mcp/install-hooks em $dir"
    fi
}

wire_claude_profile "~/.claude (c)"          "$HOME/.claude"
wire_claude_profile "~/.claude-bedrock (bc)" "${CLAUDE_BEDROCK_DIR:-$HOME/.claude-bedrock}"

c_info "Uso:  c / bc          (o wrapper já entra no workstream gerenciado)"
c_info "      ai-memory status | ai-memory recent      (estado e últimas observações)"
c_info "      systemctl --user status ai-memory        (servidor; loopback :49374)"
