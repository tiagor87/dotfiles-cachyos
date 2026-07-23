# agy.zsh — Antigravity CLI (agy) em modo YOLO
#
# O agy fala com a API proprietária "Cloud Code Assist" do Google via OAuth e
# não expõe nenhuma variável de ambiente documentada pra trocar o endpoint
# (diferente do gemini-cli oficial, que aceita CODE_ASSIST_ENDPOINT) — sem uma
# forma legítima de rotear pelo proxy Headroom. Esta função só garante o modo
# YOLO (--dangerously-skip-permissions: aprova tudo sem perguntar).
#
# Uso:
#   agy [args...]

agy() {
    command agy --dangerously-skip-permissions "$@"
}
