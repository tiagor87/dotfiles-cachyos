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
| Base | 1 | `base/install/1-yay.sh` | Instala o **yay** (helper de AUR, do repo CachyOS) + **base-devel/git** — pré-requisito para as etapas que instalam pacotes do AUR |
| Desktop | 0 | `desktop/install/0-monitors.sh` | Configura os **monitores**: resolução + **refresh máximos** (gera `~/.config/niri/outputs.kdl`, incluído pelo `config.kdl`); pergunta rotação/reposição; portrait → coluna 100%. Roda dentro da sessão niri |
| Desktop | 1 | `desktop/install/1-niri.sh` | Instala o **niri** + utilitários da sessão (fuzzel, swaybg, playerctl, brightnessctl, xwayland-satellite, portais XDG) — o lock é o do DMS, não o swaylock (ver 9-lock.sh) |
| Desktop | 2 | `desktop/install/2-dms.sh` | Instala o **DankMaterialShell** (`dms-shell`) + deps (matugen, wl-clipboard, cliphist, cava, qt6-multimedia, inter-font, ícones Material Symbols do AUR) e habilita o `dms.service` (autostart) |
| Desktop | 3 | `desktop/install/3-greeter.sh` | Login via **greeter do DMS** (greetd): instala `greetd` + `greetd-dms-greeter-git` (pacman/yay), habilita com `dms greeter enable` (substitui o SDDM) + `sync` (wallpaper dinâmico); adiciona `pam_gnome_keyring` ao `/etc/pam.d/greetd` (auto-unlock) e confirma numlock. ⚠️ crítico de login |
| Desktop | 4 | `desktop/install/4-symlinks.sh` | **Linka os configs** do repo: `config.kdl` → `~/.config/niri/` e `settings.json` → `~/.config/DankMaterialShell/`; cria stubs dos `include`s auto-gerados e valida o config do niri |
| Desktop | 5 | `desktop/install/5-wallpapers.sh` | Monta a **biblioteca de wallpapers** em **pasta única** (`~/<Pictures>/Wallpapers`, prefixo por coleção) p/ a ciclagem do DMS percorrer tudo: copia a coleção local do CachyOS; coleções de anime/games/Catppuccin são opt-in (`DOTFILES_WALLPAPERS_FETCH=1`) |
| Desktop | 6 | `desktop/install/6-profile-picture.sh` | Define a **foto de perfil** (`desktop/dms/profile.png`) via AccountsService (sem sudo) — usada pelo DMS/lock screen. Idempotente |
| Desktop | 7 | `desktop/install/7-browser.sh` | Instala o **Brave Origin** (repo oficial CachyOS); Widevine (DRM) via `brave://settings`, sem pacote extra |
| Desktop | 8 | `desktop/install/8-keyboard.sh` | **Layout de teclado** via `localectl set-x11-keymap` (niri lê do `org.freedesktop.locale1`): escolhe entre BR ABNT2 ou US Intl com a tecla "/" do ABNT2 preservada por uma variante xkb custom (`desktop/xkb/symbols/custom`, linkada para `~/.config/xkb/`). Interativo; pula sem TTY. **Acentuação em apps GTK4 nativos** (Ghostty) depende do `GTK_IM_MODULE "gtk-im-context-simple"` no bloco `environment` do `config.kdl` — sem IME, o GTK não compõe dead keys sozinho no Wayland |
| Desktop | 9 | `desktop/install/9-lock.sh` | **Lock da máquina via DMS** (substitui o swaylock): o `Super+Alt+L` chama `dms ipc call lock lock` (mesma UI do greeter) e `lockBeforeSuspend` fica ligado; valida o wiring e **remove o swaylock** (com confirmação, guarda de dependência). Idempotente |
| Desktop | 10 | `desktop/install/10-fingerprint.sh` | **Sensor de digital** (fprintd), se houver leitor: detecta via D-Bus, **cadastra uma digital** (interativo), liga a digital no lock e no greeter do DMS (`enableFprint`/`greeterEnableFprint`) e, opcional, no **sudo** (`pam_fprintd`, senha como fallback). Sem leitor, sai sem alterar nada |
| Terminal | 1 | `terminal/install/1-wezterm.sh` | Instala o **WezTerm** + **Ghostty** + **JetBrainsMono Nerd Font** + **nodejs** (equalize de panes) |
| Terminal | 2 | `terminal/install/2-symlinks.sh` | Linka `wezterm.lua`/`equalize.js` → `~/.config/wezterm/` e `config` → `~/.config/ghostty/`, cria as pastas de cores do DMS (`wezterm/colors/`, `ghostty/themes/`) e valida as duas configs |
| Boot | 1 | `boot/install/1-limine-theme.sh` | Garante a paleta **Catppuccin Mocha** no `/boot/limine.conf` (idempotente, backup + checagem de sanidade das entradas; preserva o wallpaper/splash) |
| Boot | 2 | `boot/install/2-plymouth.sh` | Instala o tema **Plymouth `darth_vader`** (adi1090x, splash animado) e reconstrói o initramfs |
| Security | 1 | `security/install/1-gnome-keyring.sh` | Instala **gnome-keyring** + seahorse, habilita o `gcr-ssh-agent.socket` e integra o git (`credential.helper=libsecret`) |
| Security | 2 | `security/install/2-symlinks.sh` | Linka `environment.d/10-ssh-agent.conf` (define `SSH_AUTH_SOCK` → gcr) |
| Security | 3 | `security/install/3-cloudflare-warp.sh` | Instala **Cloudflare WARP** (`cloudflare-warp-bin` do AUR), habilita+inicia o `warp-svc.service` e **registra a conta** (gratuita/anônima). Não conecta sozinho — `warp-cli connect` fica a cargo do usuário. Idempotente |
| Shell | 1 | `shell/install/1-zsh.sh` | Instala **zsh** + **fzf** + **zoxide** + plugins (autosuggestions, syntax-highlighting), **Oh My Zsh** (unattended) e define o zsh como shell padrão (`chsh`) |
| Shell | 2 | `shell/install/2-symlinks.sh` | Linka o `.zshrc` → `~/.zshrc` |
| Shell | 3 | `shell/install/3-configure-zsh.sh` | **Config interativa** (via fzf): escolhe `ZSH_THEME` e os `plugins` e grava no `.zshrc` versionado. Pula sem TTY/fzf |
| Dev | 1 | `dev/install/1-jetbrains-toolbox.sh` | Instala o **JetBrains Toolbox** (AUR) — gerencia Rider, IntelliJ, etc. |
| Dev | 2 | `dev/install/2-docker-desktop.sh` | Instala o **Docker Desktop** (AUR), **corrige o login** (gera chave GPG + `pass init` — o credential helper do Docker no Linux usa `pass`; sem isso o Sign in não persiste) e **limita os recursos da VM** (`Cpus=4`, `MemoryMiB=4096`, `DiskSizeMiB=131072`): sem isso a VM QEMU sobe com `-smp <todos os cores>` e disputa CPU com o desktop |
| Dev | 3 | `dev/install/3-cli-tools.sh` | Instala **bun** + **AWS CLI v2** + **Terraform** + **GitHub CLI** (repo oficial) e a **Antigravity CLI** (AUR) |
| Dev | 4 | `dev/install/4-runtimes.sh` | Instala **Node.js** + **npm** e **.NET SDK** + **ASP.NET runtime** (repo oficial) |
| Dev | 5 | `dev/install/5-claude-code.sh` | Instala o **Claude Code** (+ jq), liga o `CLAUDE.md` global e as skills do repo, e a função `c` ao `.zshrc`. Se já houver config em `~/.claude`, **pergunta se é pra fazer um setup limpo** (zera `settings.json`, plugins e hooks — nunca o login nem o `projects/`) |
| Dev | 7 | `dev/install/7-headroom.sh` | Instala o **Headroom** (compressão de contexto, via `uv tool`). A integração é na função `c`, que chama `headroom wrap claude --1m` — o `wrap` sobe/reaproveita o proxy sozinho |
| Dev | 8 | `dev/install/8-claude-hud.sh` | Instala o **claude-hud** (HUD de statusline: contexto, tools, agents, todos) em `~/.claude` e configura o `statusLine` via `claude plugin install`. Idempotente |
| Dev | 9 | `dev/install/9-beekeeper-studio.sh` | Instala o **Beekeeper Studio** (AUR, binário pré-compilado) — cliente de banco de dados GUI |
| Dev | 10 | `dev/install/10-headroom-wrappers.sh` | Instala o **Codex CLI** (`openai-codex`, repo oficial) e liga as funções **`codex`**, **`codex-fugu`** e **`agy`** (Antigravity) ao `.zshrc` — todas em **YOLO + Headroom**. O `codex-fugu` só avisa se o `~/.fugu` não existir (bootstrap manual, pede API key) |
| Dev | 11 | `dev/install/11-posting.sh` | Instala o **Posting** (AUR) — cliente de API HTTP no terminal (TUI), alternativa ao Postman/Insomnia |
| Storage | 1 | `storage/install/1-windows-mounts.sh` | Monta **unidades Windows (NTFS via `ntfs3`)** escolhidas por fzf em `/mnt/<rótulo>` com `nofail` + `x-systemd.automount` (não quebra o boot/login se o disco falhar) + atalho humano `~/<rótulo>`; backup + validação do `/etc/fstab` |

---

## 🧩 Stack instalado

### Compositor & sessão (via `pacman`)
- **niri** — compositor Wayland scrollable-tiling
- **fuzzel** — launcher legado (`Mod+D`)
- **lock da máquina** — o **próprio lock do DMS** (`Super+Alt+L` → `dms ipc call lock lock`), mesma UI do greeter; sem swaylock (`fprintd` habilita a digital no lock/greeter)
- **swaybg** — wallpaper
- **playerctl** / **brightnessctl** — teclas de mídia e OSD de brilho
- **xwayland-satellite** — suporte a apps X11
- **xdg-desktop-portal-gtk** + **xdg-desktop-portal-gnome** — portais (file picker, screencast)
- **brave-origin-bin** — navegador (Widevine/DRM configurado direto em `brave://settings`)

### Shell / barra (via `pacman` + AUR)
- **dms-shell** (DankMaterialShell) — barra e UI Material 3 sobre quickshell; CLI `dms`
- **matugen** — cores dinâmicas (Material You)
- **wl-clipboard** + **cliphist** — histórico de clipboard
- **cava** — visualizador de áudio
- **qt6-multimedia** — sons do sistema
- **inter-font** — fonte de texto do DMS
- **ttf-material-symbols-variable-git** (AUR) — ícones do DMS

### Login / greeter (via `dms greeter` → greetd)
- **greetd** + **greeter do DMS** — a própria UI do DMS na tela de login: **wallpaper dinâmico** (acompanha o desktop via `dms greeter sync`), cores **Material You**, remember-last-session/user. Substitui o SDDM (pacotes via pacman/yay + `dms greeter enable`; reverter com `dms greeter uninstall`)
- **numlock** ativo no login (herdado do `config.kdl` do niri) e **auto-unlock do keyring** (`pam_gnome_keyring` no `/etc/pam.d/greetd`)
- **auto-resync do wallpaper**: o path unit `dms-greeter-resync.path` (systemd user) observa o `session.json` do DMS e roda `dms greeter sync` quando você troca o wallpaper — o login acompanha o desktop sozinho

### Terminal (via `pacman`)
- **WezTerm** — terminal GPU com **panes/splits nativos** (`Ctrl+\` horizontal, `Ctrl+-` vertical), navegação `Ctrl+Shift+hjkl`/setas, zoom `Ctrl+Shift+Z` e **equalize** `Ctrl+Shift+E` (distribui os panes da aba, via `equalize.js`/node). Tema **Catppuccin Mocha** como fallback, sobrescrito por cores **Material You dinâmicas** geradas pelo DMS (`colors/dank-theme.toml` via matugen) que acompanham o wallpaper (recolore ao vivo pelo watch do config). Abre no `Mod+T` do niri. `Shift+Enter` = nova linha (CSI u, p/ Claude Code/nvim)
- **Ghostty** — terminal alternativo com a **mesma fonte e o mesmo tema** do WezTerm: JetBrainsMono Nerd Font 11.5, célula 10% mais alta (`adjust-cell-height`, equivale ao `line_height = 1.1`), opacidade 0.92 e Catppuccin Mocha como fallback, sobrescrito pelas cores Material You do DMS (`~/.config/ghostty/themes/dankcolors` via matugen, incluído com `config-file = ?themes/dankcolors`). **Panes com os mesmos atalhos do WezTerm** (`Ctrl+\`/`Ctrl+-` split, `Ctrl+Shift+hjkl`/setas navega, `Ctrl+Shift+Z` zoom, `Ctrl+Shift+E` equaliza — aqui é ação nativa, sem o `equalize.js`); as abas ficam com os defaults do Ghostty. Abre no `Mod+Enter` do niri
- **JetBrainsMono Nerd Font** — fonte com ícones/ligaduras
- **nodejs** — roda o `equalize.js` (distribuição igual dos panes)

### Shell (via `pacman` + script)
- **zsh** + **Oh My Zsh** — shell padrão; `.zshrc` versionado (tema `robbyrussell`, plugins `git`/`fzf`/`sudo`). Configurável por **fzf** no setup (`3-configure-zsh.sh`) — escolhe tema + plugins — ou editando o `.zshrc` direto
- **fzf** — fuzzy finder (`Ctrl+R` histórico, `Ctrl+T` arquivos, `Alt+C` cd) via plugin do OMZ
- **zsh-autosuggestions** + **zsh-syntax-highlighting** (pacman) — sugestões e realce na linha de comando

### Dev (via `pacman` + AUR)
- **JetBrains Toolbox** (AUR) — gerencia Rider, IntelliJ, etc.
- **Docker Desktop** (AUR) — autostart no login (serviço de usuário); login corrigido via `pass`/GPG. **VM limitada** a 4 vCPUs / 4 GiB RAM / 128 GiB de teto de disco em `~/.docker/desktop/settings-store.json` (vale após `docker desktop restart`). Ajustável por env: `DD_CPUS`, `DD_MEMORY_MIB`, `DD_DISK_MIB`. Reduzir o teto de disco pede confirmação — pode fazer o Docker recriar o `Docker.raw`
- **bun** — runtime/toolkit JS
- **AWS CLI v2** — `aws`
- **Terraform** — `terraform`
- **GitHub CLI** — `gh`
- **Node.js** + **npm** — runtime JS
- **.NET SDK** + **ASP.NET runtime** — desenvolvimento .NET (Rider)
- **Claude Code** (`claude`) — a função `c` (`dev/claude/claude.zsh`) roda na pasta atual, em YOLO, através do Headroom. `c [args...]` · `c --no-hr [args...]` (direto na API, sem Headroom) · `CLAUDE_MODEL=... c` (troca o modelo). O modelo é fixado em `claude-opus-5` porque o `--1m` do Headroom escreve `ANTHROPIC_MODEL=<opus>[1m]` e o `<opus>` default dele é uma geração atrás — **precisa de bump a cada modelo novo**. `CLAUDE.md` global versionado em `dev/claude/`
- **Headroom** (`headroom-ai`, via `uv tool`) — compressão de contexto p/ o Claude Code, via `headroom wrap claude --1m`. **Não** dá pra trocar o `wrap` por `ANTHROPIC_BASE_URL`: com a base URL apontando pra um host customizado, o Claude Code aplica um gate client-side que desliga a janela de 1M tokens (headroom#1158), o carregamento de tools sob demanda (headroom#746) e o `/remote-control`
- **RTK** ([rtk-ai/rtk](https://github.com/rtk-ai/rtk)) — camada **complementar** ao Headroom, não concorrente. O Headroom comprime o contexto depois que os tokens já estão na request e trava no `prefix_frozen` (não comprime se isso invalidar o prefixo do prompt cache); o rtk filtra a saída dos comandos de shell **antes** dela virar request, onde não há prefixo pra invalidar. **Não precisa instalar**: o `headroom wrap` embarca o binário em `~/.headroom/bin/rtk`, symlinka em `~/.local/bin/` e registra o hook `PreToolUse` sozinho — nada de `rtk-bin` do AUR, que só criaria um segundo binário disputando o PATH. Economia real: `rtk gain`. Escape por comando: `rtk proxy <cmd>`
- **claude-hud** ([jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud)) — plugin de marketplace do Claude Code; HUD na statusline (contexto, tools, agents, todos)
- **Beekeeper Studio** (AUR, `beekeeper-studio-bin`) — cliente de banco de dados GUI
- **Codex CLI** (`openai-codex`) + **codex-fugu** — funções `codex` / `codex-fugu` (`dev/codex/codex.zsh`) sempre em **YOLO** (sem sandbox/confirmação) e via Headroom. O `codex-fugu` depende do bootstrap manual de [SakanaAI/fugu](https://github.com/SakanaAI/fugu) em `~/.fugu`
- **Antigravity CLI** (AUR, `antigravity-cli`) — função `agy` (`dev/antigravity/agy.zsh`) em modo YOLO
- **Posting** (AUR, `posting`) — cliente de API HTTP no terminal (TUI); coleções em `~/.local/share/posting/`, config via `posting locate config`

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
| `Mod+T` | abre o WezTerm |
| `Mod+Enter` | abre o Ghostty |
| `Mod+↑` / `Mod+↓` | navega foco (janela na coluna → transborda p/ workspace) |
| `Mod+Shift+↑/↓` · `Mod+Ctrl+↑/↓` | move a janela entre workspaces |
| `Mod+J` / `Mod+K` | foco de janela na coluna |

**WezTerm:** `Shift+Enter` = nova linha (CSI u, p/ Claude Code/nvim). Panes: `Ctrl+\`/`Ctrl+-` split, `Ctrl+Shift+hjkl` navega, `Ctrl+Shift+E` equaliza.

**Ghostty:** mesmos atalhos de panes do WezTerm (`Ctrl+\`/`Ctrl+-`, `Ctrl+Shift+hjkl`, `Ctrl+Shift+Z`, `Ctrl+Shift+E`). `Ctrl+Shift+,` recarrega a config. Abas nos defaults: `Ctrl+Shift+T` nova, `Ctrl+Tab`/`Ctrl+Shift+Tab` alterna, `Ctrl+W` fecha.

> A barra sobe automaticamente no login via **`dms.service`** (serviço systemd de usuário, habilitado pelo `2-dms.sh`) — por isso o `spawn-at-startup` do DMS fica comentado no `config.kdl` (evita duplicar o shell). Settings do DMS: ícone de engrenagem na barra, ou `dms ipc call settings toggle`.

---

## 📁 Estrutura

```
dotfiles-cachyos/
├── setup.sh                      # orquestrador (menu de categorias)
├── lib/install-helpers.sh        # pacman/AUR, symlink, serviços, log+resumo
├── .githooks/pre-commit          # bloqueia segredos no staging (git config core.hooksPath .githooks)
├── base/                         # categoria Base
│   └── install/                  # 1-yay (helper de AUR + base-devel/git)
├── desktop/                      # categoria Desktop
│   ├── install/                  # 0-monitors 1-niri 2-dms 3-greeter 4-symlinks 5-wallpapers 6-profile-picture 7-browser 8-keyboard 9-lock 10-fingerprint
│   ├── niri/config.kdl           # → ~/.config/niri/config.kdl
│   ├── xkb/symbols/custom        # → ~/.config/xkb/symbols/ (variante us_abnt2)
│   ├── dms/
│   │   ├── settings.json         # → ~/.config/DankMaterialShell/settings.json
│   │   ├── profile.png           # → foto de perfil (AccountsService)
│   │   └── greeter-resync.sh     # → ~/.config/DankMaterialShell/ (auto-resync)
│   └── systemd/                  # → ~/.config/systemd/user/ (path+service do resync)
├── terminal/                     # categoria Terminal
│   ├── install/                  # 1-wezterm 2-symlinks
│   ├── wezterm/                  # wezterm.lua + equalize.js → ~/.config/wezterm/
│   └── ghostty/                  # config (fonte/tema do WezTerm) → ~/.config/ghostty/
├── boot/                         # categoria Boot
│   ├── install/                  # 1-limine-theme 2-plymouth
│   └── limine/catppuccin-mocha.conf
├── security/                     # categoria Security
│   ├── install/                  # 1-gnome-keyring 2-symlinks 3-cloudflare-warp
│   └── environment.d/10-ssh-agent.conf  # → ~/.config/environment.d/
├── shell/                        # categoria Shell
│   ├── install/                  # 1-zsh 2-symlinks 3-configure-zsh
│   └── zsh/.zshrc                # → ~/.zshrc
├── dev/                          # categoria Dev
│   ├── install/                  # 1-jetbrains-toolbox..4-runtimes 5-claude-code 7-headroom 8-claude-hud 9-beekeeper-studio 10-headroom-wrappers 11-posting
│   ├── claude/                   # CLAUDE.md global + claude.zsh (função `c`) → linkados no .zshrc
│   ├── codex/                    # codex.zsh (funções `codex`, `codex-fugu` em YOLO) → ~/.config/codex/
│   └── antigravity/              # agy.zsh (função `agy` em YOLO) → ~/.config/antigravity/
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
