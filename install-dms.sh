#!/usr/bin/env bash
#
# install-dms.sh — Instala e integra o DankMaterialShell (quickshell) com o niri no CachyOS.
#
# É idempotente: pode ser executado várias vezes com segurança. Faz backup do
# ~/.config/niri/config.kdl antes de qualquer edição e só aplica mudanças que
# ainda não existem (usa marcadores ">>> DMS").
#
# Uso:  ./install-dms.sh
#
set -euo pipefail

NIRI_DIR="${HOME}/.config/niri"
NIRI_CONF="${NIRI_DIR}/config.kdl"
MARKER_START="// >>> DMS (DankMaterialShell) — gerenciado por install-dms.sh"
MARKER_END="// <<< DMS"

c_info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
c_warn()  { printf '\033[1;33m!\033[0m %s\n' "$*"; }
c_err()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Verificações de segurança
# ---------------------------------------------------------------------------
if [[ ${EUID} -eq 0 ]]; then
  c_err "Não rode este script como root. Ele usa sudo só onde necessário."
  exit 1
fi
if ! command -v niri >/dev/null 2>&1; then
  c_err "niri não encontrado. Instale o niri primeiro."
  exit 1
fi
if [[ ! -f ${NIRI_CONF} ]]; then
  c_err "Config do niri não encontrado em ${NIRI_CONF}."
  exit 1
fi

# AUR helper (yay ou paru) para a fonte Material Symbols
AUR_HELPER=""
for h in yay paru; do
  if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
done

# ---------------------------------------------------------------------------
# 2. Instalação de pacotes
# ---------------------------------------------------------------------------
# dms-shell já puxa quickshell + dgop como dependências.
# O resto são features opcionais do DMS (launcher fuzzy, clipboard, OSD, etc.).
REPO_PKGS=(
  dms-shell          # o shell em si (Material 3) + CLI `dms`
  matugen            # geração de cores dinâmicas (Material You)
  wl-clipboard       # wl-copy / wl-paste (usado pelo clipboard nativo do DMS)
  cava               # visualizador de áudio
  qt6-multimedia     # sons do sistema / feedback
  brightnessctl      # controle de brilho (OSD do DMS)
  inter-font         # fonte de texto usada pelo DMS
  cups-pk-helper     # gerenciamento de impressoras (resolve warning do dms doctor)
  kimageformats      # formatos extras de imagem (resolve warning do dms doctor)
)
AUR_PKGS=(
  ttf-material-symbols-variable-git   # ícones do DMS
)

c_info "Instalando pacotes dos repositórios (pacman)..."
sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"
c_ok "Pacotes de repositório instalados."

if [[ -n ${AUR_HELPER} ]]; then
  c_info "Instalando fonte Material Symbols do AUR (${AUR_HELPER})..."
  "${AUR_HELPER}" -S --needed --noconfirm "${AUR_PKGS[@]}"
  c_ok "Fonte do AUR instalada."
else
  c_warn "Nenhum helper de AUR (yay/paru) encontrado."
  c_warn "Instale manualmente: ${AUR_PKGS[*]}"
fi

# ---------------------------------------------------------------------------
# 3. Backup do config do niri
# ---------------------------------------------------------------------------
BACKUP="${NIRI_CONF}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "${NIRI_CONF}" "${BACKUP}"
c_ok "Backup do config criado: ${BACKUP}"

# ---------------------------------------------------------------------------
# 4. Integração com o niri (idempotente)
# ---------------------------------------------------------------------------

# 4a. Desativa o waybar no startup (o DMS substitui a barra).
if grep -qE '^[[:space:]]*spawn-at-startup "waybar"' "${NIRI_CONF}"; then
  sed -i 's|^\([[:space:]]*\)spawn-at-startup "waybar"|\1// spawn-at-startup "waybar"  // desativado pelo DMS (a barra do DMS substitui)|' "${NIRI_CONF}"
  c_ok "Startup do waybar comentado (DMS provê a barra)."
else
  c_info "waybar já não está ativo no startup — ok."
fi

# 4b. Marcador informativo no config (o autostart é feito pelo dms.service,
#     habilitado mais abaixo — NÃO usamos spawn-at-startup para não duplicar).
if ! grep -qF "${MARKER_START}" "${NIRI_CONF}"; then
  cat >> "${NIRI_CONF}" <<EOF

${MARKER_START}
// O DMS é iniciado pelo serviço systemd de usuário (dms.service), habilitado
// por este script. Por isso NÃO há spawn-at-startup aqui (evita duplicar o shell).
${MARKER_END}
EOF
  c_ok "Marcador do DMS adicionado ao config do niri."
else
  c_info "Marcador do DMS já presente no config — ok."
fi

# 4c. Keybinds do DMS, inseridos DENTRO do bloco binds{}.
#     Inserimos logo após a linha do launcher fuzzel (referência estável do template).
if ! grep -qF 'dms" "ipc" "call" "spotlight"' "${NIRI_CONF}"; then
  TMP="$(mktemp)"
  awk '
    /Mod\+D .*fuzzel/ && !done {
      print
      print ""
      print "    // >>> DMS keybinds"
      print "    Mod+Space       hotkey-overlay-title=\"App Launcher (DMS)\" { spawn \"dms\" \"ipc\" \"call\" \"spotlight\" \"toggle\"; }"
      print "    Mod+Shift+Space hotkey-overlay-title=\"Clipboard (DMS)\"    { spawn \"dms\" \"ipc\" \"call\" \"clipboard\" \"toggle\"; }"
      print "    Mod+Shift+Escape hotkey-overlay-title=\"Process List (DMS)\" { spawn \"dms\" \"ipc\" \"call\" \"processlist\" \"focusOrToggle\"; }"
      print "    // <<< DMS keybinds"
      done=1
      next
    }
    { print }
  ' "${NIRI_CONF}" > "${TMP}" && mv "${TMP}" "${NIRI_CONF}"
  c_ok "Keybinds do DMS adicionados (Mod+Space, Mod+Shift+Space, Mod+Shift+Escape)."
else
  c_info "Keybinds do DMS já presentes — ok."
fi

# ---------------------------------------------------------------------------
# 5. Validação do config
# ---------------------------------------------------------------------------
c_info "Validando o config do niri..."
if niri validate -c "${NIRI_CONF}" >/dev/null 2>&1; then
  c_ok "Config do niri válido."
else
  c_err "Config do niri INVÁLIDO após edição! Restaurando backup..."
  cp -a "${BACKUP}" "${NIRI_CONF}"
  c_warn "Backup restaurado. Rode 'niri validate' para ver o erro."
  exit 1
fi

# ---------------------------------------------------------------------------
# 6. Autostart via serviço systemd (recomendado pelo DMS)
# ---------------------------------------------------------------------------
# graphical-session.target precisa estar ativo (niri rodando como sessão systemd).
c_info "Habilitando o serviço dms.service (autostart no login)..."
systemctl --user enable dms.service >/dev/null 2>&1 || true
# Reinicia para esta sessão assumir a config nova (mata instâncias manuais antes).
dms kill >/dev/null 2>&1 || true
systemctl --user restart dms.service >/dev/null 2>&1 || systemctl --user start dms.service >/dev/null 2>&1 || true
sleep 1
if systemctl --user is-active dms.service >/dev/null 2>&1; then
  c_ok "dms.service ativo e habilitado."
else
  c_warn "dms.service não ficou ativo. Verifique: systemctl --user status dms.service"
fi

# ---------------------------------------------------------------------------
# 7. Diagnóstico final
# ---------------------------------------------------------------------------
c_info "Rodando 'dms doctor' (resumo de warnings)..."
dms doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -iE "warning|Not available|Not installed|Disabled" || true

# ---------------------------------------------------------------------------
# 8. Próximos passos
# ---------------------------------------------------------------------------
cat <<'EOF'

──────────────────────────────────────────────────────────────────────
✓ DankMaterialShell instalado e integrado ao niri (via dms.service).

A barra sobe automaticamente no login. Comandos úteis:
    systemctl --user status dms.service    # estado do shell
    dms restart                            # reinicia o shell
    dms doctor                             # diagnóstico/dependências

Atalhos adicionados:
    Mod+Space        → App launcher (spotlight)
    Mod+Shift+Space  → Histórico de clipboard
    Mod+Shift+Escape → Lista de processos

Configurações do DMS (tema, cores, módulos da barra):
    Ícone de engrenagem na barra, ou:  dms ipc call settings toggle

Se algo der errado, seu config anterior está no backup mostrado acima.
──────────────────────────────────────────────────────────────────────
EOF
