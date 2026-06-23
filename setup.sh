#!/usr/bin/env bash
# setup.sh — Instalação do ambiente (CachyOS / niri)
#
# Orquestrador idempotente: mostra um menu de categorias e roda, em ordem
# numérica, os scripts N-*.sh de cada uma. Cada script roda sob um cabeçalho
# `▶ [i/N] <descrição>`, extraída do comentário-cabeçalho do próprio script
# (`# nome.sh — descrição`). Ao final, exibe um resumo agrupado por categoria.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT="$SCRIPT_DIR"

# shellcheck source=lib/install-helpers.sh
source "$SCRIPT_DIR/lib/install-helpers.sh"

if [[ ${EUID} -eq 0 ]]; then
    c_err "Não rode o setup como root. Ele usa sudo só onde necessário."
    exit 1
fi

# --- Definição de categorias (ordem importa) -------------------------------
# Formato: "Nome|descrição|dir1[:dir2...]" (dirs relativos a DOTFILES_ROOT)
CATEGORIES=(
    "Desktop|niri (WM) + DankMaterialShell + SDDM|desktop/install"
    "Terminal|kitty (animações de cursor + cores Material You)|terminal/install"
)

# Só scripts numerados (N-*.sh) entram no pipeline, em ordem numérica.
category_scripts() {
    local dirs="$1" dir
    for dir in ${dirs//:/ }; do
        [[ -d $DOTFILES_ROOT/$dir ]] || continue
        find "$DOTFILES_ROOT/$dir" -maxdepth 1 -type f -name '[0-9]*-*.sh' 2>/dev/null
    done | sort -V
}

# Descrição amigável a partir do cabeçalho `# nome.sh — descrição`
# (procura a linha do comentário-cabeçalho; a linha 1 é o shebang)
script_description() {
    local line desc
    line=$(grep -m1 -E '^#[[:space:]]*[^[:space:]]+\.sh[[:space:]]*(—|–|-)' "$1")
    desc=$(printf '%s\n' "$line" | sed -E 's/^#[[:space:]]*[^[:space:]]+\.sh[[:space:]]*(—|–|-)[[:space:]]*//')
    [[ -n $desc ]] && echo "$desc" || basename "$1" .sh
}

# --- Menu ------------------------------------------------------------------
clear 2>/dev/null || true
printf '%s╔══════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
printf '%s║          Setup — Seleção de Categorias            ║%s\n' "$C_CYAN" "$C_RESET"
printf '%s╚══════════════════════════════════════════════════╝%s\n\n' "$C_CYAN" "$C_RESET"

names=(); descs=(); dirs=()
i=1
for entry in "${CATEGORIES[@]}"; do
    IFS='|' read -r name desc dir <<<"$entry"
    names+=("$name"); descs+=("$desc"); dirs+=("$dir")
    count=$(category_scripts "$dir" | grep -c . || true)
    label=$([[ $count -eq 1 ]] && echo "1 script" || echo "$count scripts")
    printf '  %s[%d]%s %-16s %s%s%s\n' "$C_CYAN" "$i" "$C_RESET" "$name" "$C_DIM" "$label" "$C_RESET"
    printf '      %s%s%s\n' "$C_DIM" "$desc" "$C_RESET"
    i=$((i+1))
done
printf '\n  [A] Todas    [0] Sair\n\n'

read -rp "Selecione (ex: 1 ou A): " selection

[[ $selection =~ ^0$ ]] && { c_info "Saindo."; exit 0; }

selected=()
if [[ $selection =~ ^[Aa]$ ]]; then
    selected=($(seq 1 ${#names[@]}))
else
    for tok in $selection; do
        [[ $tok =~ ^[0-9]+$ ]] && (( tok >= 1 && tok <= ${#names[@]} )) && selected+=("$tok")
    done
fi

[[ ${#selected[@]} -eq 0 ]] && { c_err "Nenhuma categoria válida selecionada."; exit 1; }

# --- Execução --------------------------------------------------------------
for idx in "${selected[@]}"; do
    n=$((idx-1))
    set_category "${names[$n]}"
    mapfile -t scripts < <(category_scripts "${dirs[$n]}")
    [[ ${#scripts[@]} -eq 0 ]] && continue

    printf '\n%s' "$C_MAGENTA"
    printf '═══ %s ' "${names[$n]}"; printf '═%.0s' $(seq 1 40)
    printf '%s\n' "$C_RESET"

    j=1
    for script in "${scripts[@]}"; do
        printf '%s▶ [%d/%d]%s %s\n' "$C_CYAN" "$j" "${#scripts[@]}" "$C_RESET" "$(script_description "$script")"
        bash "$script"
        j=$((j+1))
    done
done

show_summary
