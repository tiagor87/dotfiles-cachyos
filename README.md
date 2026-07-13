<div align="center">

# 🐧 dotfiles-cachyos

**Setup automatizado de desktop Wayland no CachyOS — niri, DankMaterialShell e SDDM, num comando.**

![CachyOS](https://img.shields.io/badge/CachyOS-Arch--based-1793D1?logo=archlinux&logoColor=white)
![niri](https://img.shields.io/badge/niri-scrollable--tiling-7C3AED)
![DankMaterialShell](https://img.shields.io/badge/DMS-Material%203-D97757)
![License](https://img.shields.io/badge/license-MIT-green)

*Um script. Um compositor scrollable-tiling. Uma barra Material You. SDDM no boot.* ☕

</div>

---

## ⚡ TL;DR

```bash
git clone git@github.com:tiagor87/dotfiles-cachyos.git
cd dotfiles-cachyos
./setup.sh
```

> 💡 Rode como **usuário normal** (não root). O script chama `sudo` só onde precisa (pacman, habilitar o SDDM).

---

## 🎯 O que isso faz

O `setup.sh` é um orquestrador idempotente. Ao rodar, mostra um **menu de categorias** com a descrição e o nº de scripts de cada uma, e executa só os da(s) escolhida(s) — cada script roda sob um cabeçalho `▶ [i/N] <descrição>`, extraída do comentário-cabeçalho do próprio script (`# nome.sh — descrição`). Cada script é seguro de rodar várias vezes.

A instalação de pacotes **e a criação dos symlinks** mostra uma linha por item com status:

```
  → niri                                     ✓ 25.05.1-1
  → fuzzel                                   = já instalado (1.12.1-1)
  → dms-shell                                ↑ 0.9.0 → 0.9.2
  → niri config.kdl                          ✓ vinculado
  → sddm.service                             ⚙ habilitado
```

No final, é exibido um **resumo agrupado por categoria** (instalados / atualizados / já presentes / configurados / falhos).

> 📐 Só scripts com prefixo numérico (`N-*.sh`) entram no pipeline, em ordem numérica — auxiliares sem número na pasta `install/` são ignorados.

### Pipeline de instalação

| Categoria | # | Script | Responsabilidade |
|-----------|---|--------|------------------|
| Desktop | 0 | `desktop/install/0-monitors.sh` | Configura os **monitores**: resolução + **refresh máximos** (gera `~/.config/niri/outputs.kdl`, incluído pelo `config.kdl`); pergunta rotação/reposição; portrait → coluna 100%. Roda dentro da sessão niri |
| Desktop | 1 | `desktop/install/1-niri.sh` | Instala o **niri** + utilitários da sessão (fuzzel, swaylock, swaybg, playerctl, brightnessctl, xwayland-satellite, portais XDG) |
| Desktop | 2 | `desktop/install/2-dms.sh` | Instala o **DankMaterialShell** (`dms-shell`) + deps (matugen, wl-clipboard, cliphist, cava, qt6-multimedia, inter-font, ícones Material Symbols) e habilita o `dms.service` (autostart) |
| Desktop | 3 | `desktop/install/3-greeter.sh` | Login via **greeter do DMS** (greetd): `dms greeter install` (substitui o SDDM) + `sync` (wallpaper dinâmico); adiciona `pam_gnome_keyring` ao `/etc/pam.d/greetd` (auto-unlock) e confirma numlock. ⚠️ crítico de login |
| Desktop | 4 | `desktop/install/4-symlinks.sh` | **Linka os configs** do repo: `config.kdl` → `~/.config/niri/` e `settings.json` → `~/.config/DankMaterialShell/`; cria stubs dos `include`s auto-gerados e valida o config do niri |
| Desktop | 5 | `desktop/install/5-wallpapers.sh` | Monta a **biblioteca de wallpapers** em **pasta única** (`~/<Pictures>/Wallpapers`, prefixo por coleção) p/ a ciclagem do DMS percorrer tudo: copia a coleção local do CachyOS; coleções de anime/games/Catppuccin são opt-in (`DOTFILES_WALLPAPERS_FETCH=1`) |
| Desktop | 6 | `desktop/install/6-profile-picture.sh` | Define a **foto de perfil** (`desktop/dms/profile.png`) via AccountsService (sem sudo) — usada pelo DMS/lock screen. Idempotente |
| Desktop | 7 | `desktop/install/7-browser.sh` | Instala o **Brave Origin** (repo oficial CachyOS); Widevine (DRM) via `brave://settings`, sem pacote extra |
| Terminal | 1 | `terminal/install/1-wezterm.sh` | Instala o **WezTerm** + **JetBrainsMono Nerd Font** + **nodejs** (equalize de panes) |
| Terminal | 2 | `terminal/install/2-symlinks.sh` | Linka `wezterm.lua`/`equalize.js` → `~/.config/wezterm/`, cria `~/.config/wezterm/colors/` (cores do DMS) e valida a config do WezTerm |
| Boot | 1 | `boot/install/1-limine-theme.sh` | Garante a paleta **Catppuccin Mocha** no `/boot/limine.conf` (idempotente, backup + checagem de sanidade das entradas; preserva o wallpaper/splash) |
| Boot | 2 | `boot/install/2-plymouth.sh` | Instala o tema **Plymouth `darth_vader`** (adi1090x, splash animado) e reconstrói o initramfs |
| Security | 1 | `security/install/1-gnome-keyring.sh` | Instala **gnome-keyring** + seahorse, habilita o `gcr-ssh-agent.socket` e integra o git (`credential.helper=libsecret`) |
| Security | 2 | `security/install/2-symlinks.sh` | Linka `environment.d/10-ssh-agent.conf` (define `SSH_AUTH_SOCK` → gcr) |
| Shell | 1 | `shell/install/1-zsh.sh` | Instala **zsh** + **fzf** + plugins (autosuggestions, syntax-highlighting), **Oh My Zsh** (unattended) e define o zsh como shell padrão (`chsh`) |
| Shell | 2 | `shell/install/2-symlinks.sh` | Linka o `.zshrc` → `~/.zshrc` |
| Shell | 3 | `shell/install/3-configure-zsh.sh` | **Config interativa** (via fzf): escolhe `ZSH_THEME` e os `plugins` e grava no `.zshrc` versionado. Pula sem TTY/fzf |
| Dev | 1 | `dev/install/1-jetbrains-toolbox.sh` | Instala o **JetBrains Toolbox** (via pacman) — gerencia Rider, IntelliJ, etc. |
| Dev | 2 | `dev/install/2-docker-desktop.sh` | Instala o **Docker Desktop** (via pacman) e **corrige o login**: gera chave GPG + `pass init` (o credential helper do Docker no Linux usa `pass`; sem isso o Sign in não persiste) |
| Dev | 3 | `dev/install/3-cli-tools.sh` | Instala **bun** + **AWS CLI v2** (repo oficial) |
| Dev | 4 | `dev/install/4-runtimes.sh` | Instala **Node.js** + **npm** e **.NET SDK** + **ASP.NET runtime** (repo oficial) |
| Dev | 5 | `dev/install/5-claude-code.sh` | Instala o **Claude Code** (+ jq), liga o `CLAUDE.md` global e a função `c` de **perfis isolados** (`CLAUDE_CONFIG_DIR` por perfil) ao `.zshrc`; seed do perfil `default` |
| Dev | 6 | `dev/install/6-claude-profiles.sh` | **Pergunta os perfis** do Claude Code durante a instalação (cria/edita em `~/.claude_profiles.json`, com `CLAUDE.md` linkado por perfil) |
| Dev | 7 | `dev/install/7-headroom.sh` | Instala o **Headroom** (compressão de contexto, via `uv tool`). A integração é na função `c`: ela lança `headroom wrap claude` por perfil — todos os perfis roteiam pelo Headroom |
| Dev | 8 | `dev/install/8-claude-hud.sh` | Instala o **claude-hud** (HUD de statusline: contexto, tools, agents, todos) em **todos os perfis** do Claude Code, lendo `~/.claude_profiles.json`; configura o `statusLine` de cada perfil via `claude plugin install`. Idempotente por perfil |
| Dev | 9 | `dev/install/9-beekeeper-studio.sh` | Instala o **Beekeeper Studio** (via pacman, binário pré-compilado) — cliente de banco de dados GUI |
| Storage | 1 | `storage/install/1-windows-mounts.sh` | Monta **unidades Windows (NTFS via `ntfs3`)** escolhidas por fzf em `/mnt/<rótulo>` com `nofail` + `x-systemd.automount` (não quebra o boot/login se o disco falhar) + atalho humano `~/<rótulo>`; backup + validação do `/etc/fstab` |

---

## 🧩 Stack instalado

### Compositor & sessão (via `pacman`)
- **niri** — compositor Wayland scrollable-tiling
- **fuzzel** — launcher legado (`Mod+D`)
- **swaylock** — lock screen (`Super+Alt+L`)
- **swaybg** — wallpaper
- **playerctl** / **brightnessctl** — teclas de mídia e OSD de brilho
- **xwayland-satellite** — suporte a apps X11
- **xdg-desktop-portal-gtk** + **xdg-desktop-portal-gnome** — portais (file picker, screencast)
- **brave-origin-bin** — navegador (Widevine/DRM configurado direto em `brave://settings`)

### Shell / barra (via `pacman`)
- **dms-shell** (DankMaterialShell) — barra e UI Material 3 sobre quickshell; CLI `dms`
- **matugen** — cores dinâmicas (Material You)
- **wl-clipboard** + **cliphist** — histórico de clipboard
- **cava** — visualizador de áudio
- **qt6-multimedia** — sons do sistema
- **inter-font** — fonte de texto do DMS
- **ttf-material-symbols-variable-git** — ícones do DMS

### Login / greeter (via `dms greeter` → greetd)
- **greetd** + **greeter do DMS** — a própria UI do DMS na tela de login: **wallpaper dinâmico** (acompanha o desktop via `dms greeter sync`), cores **Material You**, remember-last-session/user. Substitui o SDDM (`dms greeter install`; reverter com `dms greeter uninstall`)
- **numlock** ativo no login (herdado do `config.kdl` do niri) e **auto-unlock do keyring** (`pam_gnome_keyring` no `/etc/pam.d/greetd`)
- **auto-resync do wallpaper**: o path unit `dms-greeter-resync.path` (systemd user) observa o `session.json` do DMS e roda `dms greeter sync` quando você troca o wallpaper — o login acompanha o desktop sozinho

### Terminal (via `pacman`)
- **WezTerm** — terminal GPU com **panes/splits nativos** (`Ctrl+\` horizontal, `Ctrl+-` vertical), navegação `Ctrl+Shift+hjkl`/setas, zoom `Ctrl+Shift+Z` e **equalize** `Ctrl+Shift+E` (distribui os panes da aba, via `equalize.js`/node). Tema **Catppuccin Mocha** como fallback, sobrescrito por cores **Material You dinâmicas** geradas pelo DMS (`colors/dank-theme.toml` via matugen) que acompanham o wallpaper (recolore ao vivo pelo watch do config). Terminal padrão do niri (`Mod+T` **e `Mod+Enter`**). `Shift+Enter` = nova linha (CSI u, p/ Claude Code/nvim)
- **JetBrainsMono Nerd Font** — fonte com ícones/ligaduras
- **nodejs** — roda o `equalize.js` (distribuição igual dos panes)

### Shell (via `pacman` + script)
- **zsh** + **Oh My Zsh** — shell padrão; `.zshrc` versionado (tema `robbyrussell`, plugins `git`/`fzf`/`sudo`). Configurável por **fzf** no setup (`3-configure-zsh.sh`) — escolhe tema + plugins — ou editando o `.zshrc` direto
- **fzf** — fuzzy finder (`Ctrl+R` histórico, `Ctrl+T` arquivos, `Alt+C` cd) via plugin do OMZ
- **zsh-autosuggestions** + **zsh-syntax-highlighting** (pacman) — sugestões e realce na linha de comando

### Dev (via `pacman`)
- **JetBrains Toolbox** — gerencia Rider, IntelliJ, etc.
- **Docker Desktop** — autostart no login (serviço de usuário); login corrigido via `pass`/GPG
- **bun** — runtime/toolkit JS
- **AWS CLI v2** — `aws`
- **Node.js** + **npm** — runtime JS
- **.NET SDK** + **ASP.NET runtime** — desenvolvimento .NET (Rider)
- **Claude Code** (`claude`) — com **perfis isolados**: a função `c` lê `~/.claude_profiles.json` (`{ "Nome": { "WorkDir": ... } }`), define `CLAUDE_CONFIG_DIR` por perfil (config/login isolados) e roda na pasta atual. `c` (seletor) · `c add <nome> [dir]` · `c ls` · `c rm <nome>`. `CLAUDE.md` global versionado em `dev/claude/`. Os perfis são perguntados no setup (`6-claude-profiles.sh`)
- **Headroom** (`headroom-ai`, via `uv tool`) — compressão de contexto p/ o Claude Code. A função `c` lança via `headroom wrap claude` (sobe o proxy e roteia a API) em qualquer perfil
- **claude-hud** ([jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud)) — plugin de marketplace do Claude Code; HUD na statusline (contexto, tools, agents, todos), instalado e configurado em todos os perfis
- **Beekeeper Studio** (`beekeeper-studio-bin`) — cliente de banco de dados GUI

### Storage
- **ntfs-3g** (tools) + driver **`ntfs3`** (kernel) — monta unidades Windows (NTFS) com `nofail`/automount; atalho `~/<rótulo>`

---

## ⌨️ Atalhos (já no `config.kdl`)

**DMS:**

| Atalho | Ação |
|--------|------|
| `Mod+Space` | App launcher (spotlight) |
| `Mod+Shift+Space` | Histórico de clipboard |
| `Mod+Shift+Escape` | Lista de processos |

**niri (customizados):**

| Atalho | Ação |
|--------|------|
| `Mod+T` / `Mod+Enter` | abre o terminal (WezTerm) |
| `Mod+↑` / `Mod+↓` | navega foco (janela na coluna → transborda p/ workspace) |
| `Mod+Shift+↑/↓` · `Mod+Ctrl+↑/↓` | move a janela entre workspaces |
| `Mod+J` / `Mod+K` | foco de janela na coluna |

**WezTerm:** `Shift+Enter` = nova linha (CSI u, p/ Claude Code/nvim). Panes: `Ctrl+\`/`Ctrl+-` split, `Ctrl+Shift+hjkl` navega, `Ctrl+Shift+E` equaliza.

> A barra sobe automaticamente no login via **`dms.service`** (serviço systemd de usuário, habilitado pelo `2-dms.sh`) — por isso o `spawn-at-startup` do DMS fica comentado no `config.kdl` (evita duplicar o shell). Settings do DMS: ícone de engrenagem na barra, ou `dms ipc call settings toggle`.

---

## 📁 Estrutura

```
dotfiles-cachyos/
├── setup.sh                      # orquestrador (menu de categorias)
├── lib/install-helpers.sh        # pacman, symlink, serviços, log+resumo
├── .githooks/pre-commit          # bloqueia segredos no staging (git config core.hooksPath .githooks)
├── desktop/                      # categoria Desktop
│   ├── install/                  # 0-monitors 1-niri 2-dms 3-greeter 4-symlinks 5-wallpapers 6-profile-picture 7-browser
│   ├── niri/config.kdl           # → ~/.config/niri/config.kdl
│   ├── dms/
│   │   ├── settings.json         # → ~/.config/DankMaterialShell/settings.json
│   │   ├── profile.png           # → foto de perfil (AccountsService)
│   │   └── greeter-resync.sh     # → ~/.config/DankMaterialShell/ (auto-resync)
│   └── systemd/                  # → ~/.config/systemd/user/ (path+service do resync)
├── terminal/                     # categoria Terminal
│   ├── install/                  # 1-wezterm 2-symlinks
│   └── wezterm/                  # wezterm.lua + equalize.js → ~/.config/wezterm/
├── boot/                         # categoria Boot
│   ├── install/                  # 1-limine-theme 2-plymouth
│   └── limine/catppuccin-mocha.conf
├── security/                     # categoria Security
│   ├── install/                  # 1-gnome-keyring 2-symlinks
│   └── environment.d/10-ssh-agent.conf  # → ~/.config/environment.d/
├── shell/                        # categoria Shell
│   ├── install/                  # 1-zsh 2-symlinks 3-configure-zsh
│   └── zsh/.zshrc                # → ~/.zshrc
├── dev/                          # categoria Dev
│   ├── install/                  # 1-jetbrains-toolbox..4-runtimes 5-claude-code 6-claude-profiles 7-headroom 8-claude-hud 9-beekeeper-studio
│   └── claude/                   # CLAUDE.md global + claude.zsh (função `c`, perfis) → linkados no .zshrc
└── storage/                      # categoria Storage
    └── install/                  # 1-windows-mounts (NTFS/ntfs3, nofail)
```

> 🔁 Os configs versionados são **linkados** (symlink) para suas localizações reais pelo `4-symlinks.sh` — editar o arquivo no repo reflete na hora no sistema. Os arquivos `~/.config/niri/dms/*.kdl` são **auto-gerados** pelo DMS (cores, layout etc.) e por isso **não** são versionados.

---

## ➕ Adicionando uma categoria

1. Crie a pasta `<categoria>/install/` com scripts `N-*.sh`.
2. Cada script começa com `# nome.sh — descrição` (vira o título no pipeline) e faz `source "${DOTFILES_ROOT}/lib/install-helpers.sh"`.
3. Registre a categoria no array `CATEGORIES` do `setup.sh`.

---

## 📜 Licença

MIT — veja [LICENSE](LICENSE).
