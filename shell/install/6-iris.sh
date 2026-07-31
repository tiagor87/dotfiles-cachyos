#!/usr/bin/env bash
# 6-iris.sh — IRIS (menu de autocomplete no TTY, estilo IntelliSense; sucessor do Fig)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# O quickstart é `curl -sSL .../install.sh | sh`, que baixa o binário da release
# pra /usr/local/bin e chama `iris setup`. Aqui vem do AUR (mesma release, com
# sha256 pinado no PKGBUILD + completions do zsh empacotadas).
# ATENÇÃO ao nome: no AUR existem vários "iris" de projetos diferentes (emulador,
# tema GTK, CLI de bots). O deste repo é o iris-autocomplete-bin
# (versenilvis/IRIS); o iris-autocomplete compila do fonte e precisa de Go.
aur_install iris-autocomplete-bin

command -v /usr/bin/iris >/dev/null 2>&1 || {
    c_err "IRIS não instalado — o resto da configuração foi pulado."
    return 0 2>/dev/null || exit 0
}

# --- Instalação solta do install.sh (se houver) --------------------------------
if [[ -x /usr/local/bin/iris ]]; then
    c_warn "/usr/local/bin/iris (do install.sh) vem antes no PATH e sombreia o do pacman."
    c_warn "  remova com:  sudo rm /usr/local/bin/iris   (config/histórico ficam em ~/.config/iris)"
    log_entry shell "iris standalone" skipped "/usr/local/bin/iris sombreia /usr/bin"
fi

# --- Alias `i` ----------------------------------------------------------------
# IRIS não é hook de shell: ele ENVOLVE o shell (abre um zsh filho em raw mode e
# desenha o menu). Por isso a única integração é o alias sugerido pelo upstream —
# nada no PROMPT, nada de keybinding no zsh de fora.
ZSHRC="$DOTFILES_ROOT/shell/zsh/.zshrc"
if grep -q "alias i='iris'" "$ZSHRC" 2>/dev/null; then
    pkg_status "alias i (iris)" "= já configurado" "$C_DIM"
    log_entry shell "iris alias" skipped "alias i='iris'"
else
    c_warn "Falta o \`alias i='iris'\` em $ZSHRC — chame pelo nome cheio: iris"
    log_entry shell "iris alias" failed "alias ausente"
fi

# --- Config -------------------------------------------------------------------
# Não versionado (como o starship): quem escreve o ~/.config/iris/config.toml é o
# próprio `iris config init`, e o IRIS reescreve o arquivo ao mudar opção em
# runtime — um symlink pro repo viraria briga de escrita. Aqui só ajustamos as
# duas chaves que colidem com o resto do setup, e só enquanto estiverem no
# default (valor customizado é do usuário: não mexemos).
IRIS_CFG="$HOME/.config/iris/config.toml"
if [[ -f $IRIS_CFG ]]; then
    pkg_status "iris config.toml" "= já existe" "$C_DIM"
    log_entry shell "iris config" skipped "$IRIS_CFG"
elif /usr/bin/iris config init >/dev/null 2>&1 && [[ -f $IRIS_CFG ]]; then
    pkg_status "iris config.toml" "✓ criado (iris config init)" "$C_GREEN"
    log_entry shell "iris config" configured "$IRIS_CFG"
else
    pkg_status "iris config.toml" "! crie com: iris config init" "$C_YELLOW"
    log_entry shell "iris config" failed "iris config init"
fi

# 1) Ctrl+R fica com o atuin. Dentro do IRIS o terminal está em raw mode e ele
#    consome a tecla antes do zsh, então o default (spec ↔ history no ctrl+r)
#    esconderia a busca do atuin. ctrl+g está livre: o IRIS só intercepta
#    ctrl+a/c/e/l/u/w, tab, enter e backspace (e o MatchKey aceita ctrl+<a-z>).
# 2) O binário é do pacman (iris-autocomplete-bin) — o auto-update do IRIS
#    atualizaria por fora dele.
if [[ -f $IRIS_CFG ]]; then
    iris_set() {
        local label="$1" from="$2" to="$3"
        if grep -qF -- "$to" "$IRIS_CFG"; then
            pkg_status "$label" "= já ajustado" "$C_DIM"
            log_entry shell "$label" skipped "$to"
        elif grep -qF -- "$from" "$IRIS_CFG"; then
            sed -i "s|^${from}$|${to}|" "$IRIS_CFG"
            pkg_status "$label" "✓ $to" "$C_GREEN"
            log_entry shell "$label" configured "$from → $to"
        else
            pkg_status "$label" "! customizado — mantido" "$C_YELLOW"
            log_entry shell "$label" skipped "valor fora do default; não alterado"
        fi
    }
    iris_set "iris toggle-mode"      'toggle-mode = "ctrl+r"'  'toggle-mode = "ctrl+g"'
    iris_set "iris check-on-startup" 'check-on-startup = true' 'check-on-startup = false'
fi

c_info "Uso:  i  (ou iris) · Shift+Tab abre o menu · Tab aceita · → aceita o ghost text"
c_info "      Ctrl+G alterna spec ↔ history (o Ctrl+R segue sendo do atuin)."
