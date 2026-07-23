# codex.zsh — Codex CLI e codex-fugu via Headroom (proxy de otimização) + modo YOLO
#
# Sem perfis (diferente do claude.zsh): sempre roda na pasta atual, sempre em
# modo YOLO (--dangerously-bypass-approvals-and-sandbox: sem sandbox, sem
# confirmação de comandos).
#
# Uso:
#   codex [args...]        → Codex real, via headroom (se instalado) + YOLO
#   codex-fugu [args...]   → codex-fugu (nudge de modelo padrão), idem

codex() {
    if command -v headroom >/dev/null 2>&1; then
        headroom wrap codex -- --dangerously-bypass-approvals-and-sandbox "$@"
    else
        command codex --dangerously-bypass-approvals-and-sandbox "$@"
    fi
}

# `headroom wrap` não tem subcomando pra codex-fugu — ele sempre lança o
# binário `codex` puro, o que pularia a lógica do fugu (perfil `-p fugu`,
# aviso de modelo padrão). Em vez disso, sobe/reaproveita o proxy Headroom na
# mesma porta padrão do `codex` (8787) e só aponta o OPENAI_BASE_URL pra ele —
# o codex-fugu continua resolvendo e chamando o codex real sozinho.
codex-fugu() {
    if command -v headroom >/dev/null 2>&1; then
        local port="${HEADROOM_PORT:-8787}"
        if ! curl -fsS --max-time 1 "http://127.0.0.1:$port/livez" >/dev/null 2>&1; then
            headroom proxy -p "$port" >/tmp/headroom-proxy-codex.log 2>&1 &
            disown
            local i
            for i in $(seq 1 20); do
                curl -fsS --max-time 1 "http://127.0.0.1:$port/livez" >/dev/null 2>&1 && break
                sleep 0.25
            done
        fi
        OPENAI_BASE_URL="http://127.0.0.1:$port/v1" \
            command codex-fugu --dangerously-bypass-approvals-and-sandbox "$@"
    else
        command codex-fugu --dangerously-bypass-approvals-and-sandbox "$@"
    fi
}
