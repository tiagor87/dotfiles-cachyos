# install-helpers.sh — Helpers para instalação silenciosa + log agrupado
#
# Uso: faça `source` deste arquivo a partir do setup.sh ANTES de rodar os
# scripts de instalação. As funções e o estado do log são exportados via
# variáveis de ambiente para os scripts filhos (rodados via `bash <script>`).
#
# Convenção de status (espelha o dotfiles-windows):
#   installed  ✓   updated  ↑   skipped  =   configured  ⚙   failed  ✗

# ---------------------------------------------------------------------------
# Estado do log — persistido num arquivo para sobreviver entre subprocessos.
# Cada linha: categoria\ttipo\tnome\tstatus\tdetalhe
# ---------------------------------------------------------------------------
# Condicionais: preservam o valor herdado do env quando um script-filho
# re-source este arquivo (senão a categoria definida pelo setup.sh seria perdida).
: "${DOTFILES_LOG_FILE:=$(mktemp -t dotfiles-install-log.XXXXXX)}"
: "${CURRENT_CATEGORY:=Geral}"
export DOTFILES_LOG_FILE CURRENT_CATEGORY

# Cores
C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_RED=$'\033[1;31m'
C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_BLUE=$'\033[1;34m'
C_CYAN=$'\033[1;36m'; C_MAGENTA=$'\033[1;35m'

set_category() { export CURRENT_CATEGORY="$1"; }

# log_entry <tipo> <nome> <status> [detalhe]
log_entry() {
    # 'st' em vez de 'status' (em zsh 'status' é read-only).
    local type="$1" name="$2" st="$3" detail="${4:-}"
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$CURRENT_CATEGORY" "$type" "$name" "$st" "$detail" \
        >>"$DOTFILES_LOG_FILE"
}

# pkg_status <nome> <mensagem> <cor-ansi>
pkg_status() {
    printf '  %s→ %-42s%s %s%s%s\n' \
        "$C_DIM" "$1" "$C_RESET" "${3}" "$2" "$C_RESET"
}

# ---------------------------------------------------------------------------
# pacman (repositórios oficiais / CachyOS)
# ---------------------------------------------------------------------------

# pkg_version <pkg> → versão instalada (vazio se ausente)
pkg_version() { pacman -Q "$1" 2>/dev/null | awk '{print $2}'; }

# repo_install <pkg...> — instala cada pacote via pacman, reportando status.
# Roda numa transação por pacote (--needed) para isolar falhas; sudo é
# pré-autenticado uma vez para não repetir prompt.
repo_install() {
    sudo -v || { c_err "sudo recusado — abortando instalação de pacotes."; return 1; }
    local pkg before after out
    for pkg in "$@"; do
        before=$(pkg_version "$pkg")
        out=$(sudo pacman -S --needed --noconfirm "$pkg" 2>&1)
        after=$(pkg_version "$pkg")

        if [[ -z $after ]]; then
            pkg_status "$pkg" "✗ falhou" "$C_RED"
            log_entry pacman "$pkg" failed "$(echo "$out" | grep -iE 'error|erro' | tail -1)"
        elif [[ -z $before ]]; then
            pkg_status "$pkg" "✓ $after" "$C_GREEN"
            log_entry pacman "$pkg" installed "$after"
        elif [[ $before != "$after" ]]; then
            pkg_status "$pkg" "↑ $before → $after" "$C_YELLOW"
            log_entry pacman "$pkg" updated "$before → $after"
        else
            pkg_status "$pkg" "= já instalado ($after)" "$C_DIM"
            log_entry pacman "$pkg" skipped "$after"
        fi
    done
}

# ---------------------------------------------------------------------------
# AUR (yay / paru)
# ---------------------------------------------------------------------------

aur_helper() {
    local h
    for h in yay paru; do command -v "$h" >/dev/null 2>&1 && { echo "$h"; return; }; done
}

# aur_install <pkg...>
aur_install() {
    local helper; helper=$(aur_helper)
    if [[ -z $helper ]]; then
        local pkg
        for pkg in "$@"; do
            pkg_status "$pkg" "✗ sem helper de AUR (yay/paru)" "$C_RED"
            log_entry aur "$pkg" failed "instale yay ou paru, ou instale $pkg manualmente"
        done
        return
    fi
    # Prima o sudo com prompt VISÍVEL antes de chamar o yay/paru. Builds do AUR
    # (makepkg) são interativos/longos — NÃO redirecionamos a saída, senão o
    # prompt de senha some e a instalação parece travada.
    sudo -v || { c_err "sudo recusado — abortando instalação do AUR."; return 1; }
    local pkg before after
    for pkg in "$@"; do
        before=$(pkg_version "$pkg")
        c_info "AUR: compilando/instalando $pkg via $helper (mostra a saída; pode demorar)..."
        "$helper" -S --needed --noconfirm "$pkg"
        after=$(pkg_version "$pkg")
        if [[ -z $after ]]; then
            pkg_status "$pkg" "✗ falhou" "$C_RED"
            log_entry aur "$pkg" failed "$helper -S $pkg falhou"
        elif [[ -z $before ]]; then
            pkg_status "$pkg" "✓ $after" "$C_GREEN"
            log_entry aur "$pkg" installed "$after"
        elif [[ $before != "$after" ]]; then
            pkg_status "$pkg" "↑ $before → $after" "$C_YELLOW"
            log_entry aur "$pkg" updated "$before → $after"
        else
            pkg_status "$pkg" "= já instalado ($after)" "$C_DIM"
            log_entry aur "$pkg" skipped "$after"
        fi
    done
}

# ---------------------------------------------------------------------------
# Symlinks (porte de New-DotfilesSymlink)
# ---------------------------------------------------------------------------

# symlink <link> <target> [label]
# Faz backup de arquivo real existente (.bak), corrige symlink com alvo errado,
# e cria o link. Idempotente.
symlink() {
    local link="$1" target="$2" label="${3:-$(basename "$1")}"

    if [[ ! -e $target ]]; then
        pkg_status "$label" "✗ fonte não encontrada" "$C_RED"
        log_entry symlink "$label" failed "fonte ausente: $target"
        return
    fi

    mkdir -p "$(dirname "$link")"

    if [[ -L $link ]]; then
        if [[ "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
            pkg_status "$label" "= já vinculado" "$C_DIM"
            log_entry symlink "$label" skipped "$target"
            return
        fi
        rm -f "$link"
        ln -s "$target" "$link"
        pkg_status "$label" "↑ alvo atualizado" "$C_YELLOW"
        log_entry symlink "$label" updated "→ $target"
        return
    fi

    if [[ -e $link ]]; then
        mv "$link" "$link.bak"
        ln -s "$target" "$link"
        pkg_status "$label" "✓ vinculado (.bak criado)" "$C_GREEN"
        log_entry symlink "$label" installed "$target (original em $link.bak)"
        return
    fi

    ln -s "$target" "$link"
    pkg_status "$label" "✓ vinculado" "$C_GREEN"
    log_entry symlink "$label" installed "$target"
}

# ---------------------------------------------------------------------------
# Serviços systemd
# ---------------------------------------------------------------------------

# enable_system_service <unit> — habilita (sem iniciar) um serviço do sistema.
enable_system_service() {
    local unit="$1"
    if systemctl is-enabled "$unit" >/dev/null 2>&1; then
        pkg_status "$unit" "= já habilitado" "$C_DIM"
        log_entry service "$unit" skipped "já habilitado"
        return
    fi
    if sudo systemctl enable "$unit" >/dev/null 2>&1; then
        pkg_status "$unit" "✓ habilitado" "$C_GREEN"
        log_entry service "$unit" configured "systemctl enable $unit"
    else
        pkg_status "$unit" "✗ falhou" "$C_RED"
        log_entry service "$unit" failed "systemctl enable $unit falhou"
    fi
}

# enable_user_service <unit> — habilita+inicia um serviço de usuário.
enable_user_service() {
    local unit="$1"
    if systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
        pkg_status "$unit" "= já habilitado" "$C_DIM"
        log_entry service "$unit" skipped "já habilitado"
        return
    fi
    if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
        pkg_status "$unit" "✓ habilitado" "$C_GREEN"
        log_entry service "$unit" configured "systemctl --user enable --now $unit"
    else
        pkg_status "$unit" "✗ falhou" "$C_RED"
        log_entry service "$unit" failed "systemctl --user enable $unit falhou"
    fi
}

# ---------------------------------------------------------------------------
# Mensagens auxiliares
# ---------------------------------------------------------------------------
c_info() { printf '%s::%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
c_ok()   { printf '%s✓%s %s\n'  "$C_GREEN" "$C_RESET" "$*"; }
c_warn() { printf '%s!%s %s\n'  "$C_YELLOW" "$C_RESET" "$*"; }
c_err()  { printf '%s✗%s %s\n'  "$C_RED" "$C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Resumo final (porte de Show-InstallSummary)
# ---------------------------------------------------------------------------
show_summary() {
    printf '\n%s╔══════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
    printf '%s║                Resumo da Instalação               ║%s\n' "$C_CYAN" "$C_RESET"
    printf '%s╚══════════════════════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"

    [[ -s $DOTFILES_LOG_FILE ]] || { printf '\n(nada processado)\n'; return; }

    local total=0 failed=0 cat st
    local categories; categories=$(cut -f1 "$DOTFILES_LOG_FILE" | awk '!seen[$0]++')

    while IFS= read -r cat; do
        printf '\n%s▼ %s%s\n' "$C_CYAN" "$cat" "$C_RESET"
        for st in installed updated skipped configured failed; do
            while IFS=$'\t' read -r lcat ltype lname lstatus ldetail; do
                [[ $lcat == "$cat" && $lstatus == "$st" ]] || continue
                total=$((total+1))
                local label color
                case $st in
                    installed)  label='✓ Instalado  '; color=$C_GREEN ;;
                    updated)    label='↑ Atualizado '; color=$C_YELLOW ;;
                    skipped)    label='= Já presente'; color=$C_DIM ;;
                    configured) label='⚙ Configurado'; color=$C_CYAN ;;
                    failed)     label='✗ Falhou     '; color=$C_RED; failed=$((failed+1)) ;;
                esac
                printf '  %s%s [%-7s] %-30s %s%s\n' \
                    "$color" "$label" "$ltype" "$lname" "$ldetail" "$C_RESET"
            done <"$DOTFILES_LOG_FILE"
        done
    done <<<"$categories"

    printf '\n'
    if [[ $failed -eq 0 ]]; then
        printf '%s✅ Tudo certo — %d item(ns) processado(s).%s\n' "$C_GREEN" "$total" "$C_RESET"
    else
        printf '%s⚠️  %d falha(s) de %d item(ns) processado(s).%s\n' "$C_YELLOW" "$failed" "$total" "$C_RESET"
    fi
}
