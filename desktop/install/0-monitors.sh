#!/usr/bin/env bash
# 0-monitors.sh — Monitores: resolução + refresh MÁXIMOS, com prompt opcional de
# rotação/reposição. Gera ~/.config/niri/outputs.kdl (incluído pelo config.kdl),
# então roda ANTES da config do niri valer.
#
# - Resolução: maior modo de cada monitor. Refresh: omitimos no `mode`, e o niri
#   escolhe o MAIOR refresh para aquela resolução automaticamente.
# - Rotação/posição: perguntadas (Enter mantém o atual). Sem TTY, mantém tudo.
# - Monitor em portrait (90/270) → default-column-width 100% (tela cheia).
#
# Precisa do niri rodando (niri msg). Numa instalação nova sem sessão, pula.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

OUT="$HOME/.config/niri/outputs.kdl"
mkdir -p "$(dirname "$OUT")"

if ! command -v niri >/dev/null 2>&1 || ! niri msg --json outputs >/dev/null 2>&1; then
    c_warn "niri msg indisponível (rode dentro da sessão niri). Pulei a config de monitores."
    log_entry monitors niri skipped "sem sessão niri"
    return 0 2>/dev/null || exit 0
fi

JSON=$(niri msg --json outputs)
mapfile -t NAMES < <(printf '%s' "$JSON" | jq -r 'keys[]')

# Estado por monitor (arrays paralelos indexados pela ordem de NAMES).
declare -A RES TR X Y
for n in "${NAMES[@]}"; do
    RES[$n]=$(printf '%s' "$JSON" | jq -r --arg n "$n" '.[$n].modes | max_by(.width*.height) | "\(.width)x\(.height)"')
    TR[$n]=$(printf '%s' "$JSON" | jq -r --arg n "$n" '.[$n].logical.transform' | tr 'A-Z' 'a-z')
    X[$n]=$(printf '%s' "$JSON" | jq -r --arg n "$n" '.[$n].logical.x')
    Y[$n]=$(printf '%s' "$JSON" | jq -r --arg n "$n" '.[$n].logical.y')
    [[ -n ${TR[$n]} && ${TR[$n]} != null ]] || TR[$n]=normal
done

c_info "Monitores detectados:"
for n in "${NAMES[@]}"; do printf '   %s  %s  transform=%s  pos=%s,%s\n' "$n" "${RES[$n]}" "${TR[$n]}" "${X[$n]}" "${Y[$n]}"; done

# --- Rotação (interativo, opcional) ------------------------------------------
if [[ -t 0 && -t 1 ]]; then
    printf '\nRotacionar algum monitor? [s/N] '; read -r ans
    if [[ ${ans:-} =~ ^[Ss]$ ]]; then
        for n in "${NAMES[@]}"; do
            printf '  %s — transform [normal/90/180/270] (Enter=%s): ' "$n" "${TR[$n]}"; read -r t
            [[ -n $t ]] && TR[$n]=$t
        done
    fi
    # --- Reposição (interativo, opcional) ------------------------------------
    printf '\nReposicionar? Ordem esquerda→direita (nomes separados por espaço) ou Enter p/ manter: '
    read -r order
    if [[ -n ${order:-} ]]; then
        local_x=0
        for n in $order; do
            [[ -n ${RES[$n]:-} ]] || { c_warn "monitor '$n' desconhecido — ignorado"; continue; }
            X[$n]=$local_x; Y[$n]=0
            # largura lógica: em portrait (90/270) usa a altura do modo
            w=${RES[$n]%x*}; h=${RES[$n]#*x}
            case "${TR[$n]}" in 90|270|*-90|*-270) lw=$h ;; *) lw=$w ;; esac
            local_x=$((local_x + lw))
        done
    fi
fi

# --- Gera o outputs.kdl ------------------------------------------------------
{
    echo "// Gerado por 0-monitors.sh — resolução máxima + refresh máximo (refresh"
    echo "// omitido = niri escolhe o maior). NÃO edite à mão; rode o script de novo."
    for n in "${NAMES[@]}"; do
        echo "output \"$n\" {"
        echo "    mode \"${RES[$n]}\""
        echo "    transform \"${TR[$n]}\""
        echo "    position x=${X[$n]} y=${Y[$n]}"
        case "${TR[$n]}" in
            90|270|*-90|*-270)
                echo "    // portrait → coluna em tela cheia"
                echo "    layout {"
                echo "        default-column-width { proportion 1.0; }"
                echo "    }" ;;
        esac
        echo "}"
    done
} > "$OUT"

if niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1; then
    pkg_status "monitores" "✓ outputs.kdl gerado (${#NAMES[@]} monitor(es))" "$C_GREEN"
    log_entry monitors outputs.kdl configured "${#NAMES[@]} monitores, res/refresh máximos"
else
    pkg_status "monitores" "! gerado, mas valide o config do niri" "$C_YELLOW"
    log_entry monitors outputs.kdl configured "gerado (verifique niri validate)"
fi
