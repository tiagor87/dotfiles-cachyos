#!/usr/bin/env bash
# 13-zed.sh — Zed (editor GPU) com as cores Material You do DMS
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Zed está nos repos oficiais (extra/zed); o binário/desktop entry é `zeditor`.
repo_install zed

# O pacote do Arch instala o binário como `zeditor`. O link em ~/.local/bin
# (já no PATH pelo .zshrc) dá o `zed <path>` — symlink em vez de alias do zsh
# porque assim vale também em scripts, no `EDITOR` e no git.
symlink "$HOME/.local/bin/zed" /usr/bin/zeditor "zed (CLI)"

# O matugen do DMS grava o tema em ~/.config/zed/themes/dank-zed-theme.json
# (config `zed.toml` do dms-shell). A pasta precisa existir antes.
mkdir -p "$HOME/.config/zed/themes"

# settings.json versionado — aponta pros temas "DankShell Dark/Light" gerados
# pelo matugen. O Zed reescreve esse arquivo quando se muda algo pela UI.
symlink "$HOME/.config/zed/settings.json" \
        "$DOTFILES_ROOT/dev/zed/settings.json" \
        "zed settings.json"

# Sem o tema gerado, o Zed ignora o nome do settings.json e cai no default (One
# Dark). O template 'Zed' já vem ligado no settings.json do DMS, mas o arquivo
# só aparece na primeira regeração de cores (troca de wallpaper ou de tema).
if [[ -f $HOME/.config/zed/themes/dank-zed-theme.json ]]; then
    pkg_status "zed tema (DMS matugen)" "✓ gerado" "$C_GREEN"
    log_entry config "zed tema (DMS matugen)" configured "themes/dank-zed-theme.json"
else
    pkg_status "zed tema (DMS matugen)" "! ainda não gerado" "$C_YELLOW"
    log_entry config "zed tema (DMS matugen)" configured \
        "gere as cores: dms ipc call theme toggle (duas vezes volta pro modo atual)"
fi
