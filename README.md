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
  → alacritty                                = já instalado (0.15.1-1)
  → dms-shell                                ↑ 0.9.0 → 0.9.2
  → niri config.kdl                          ✓ vinculado
  → sddm.service                             ⚙ habilitado
```

No final, é exibido um **resumo agrupado por categoria** (instalados / atualizados / já presentes / configurados / falhos).

> 📐 Só scripts com prefixo numérico (`N-*.sh`) entram no pipeline, em ordem numérica — auxiliares sem número na pasta `install/` são ignorados.

### Pipeline de instalação

| Categoria | # | Script | Responsabilidade |
|-----------|---|--------|------------------|
| Desktop | 1 | `desktop/install/1-niri.sh` | Instala o **niri** + utilitários da sessão (alacritty, fuzzel, swaylock, swaybg, playerctl, brightnessctl, xwayland-satellite, portais XDG) |
| Desktop | 2 | `desktop/install/2-dms.sh` | Instala o **DankMaterialShell** (`dms-shell`) + deps (matugen, wl-clipboard, cliphist, cava, qt6-multimedia, inter-font, ícones Material Symbols do AUR) e habilita o `dms.service` (autostart) |
| Desktop | 3 | `desktop/install/3-sddm.sh` | Instala e habilita o **SDDM** no boot; avisa se outro display manager já estiver ativo |
| Desktop | 4 | `desktop/install/4-symlinks.sh` | **Linka os configs** do repo: `config.kdl` → `~/.config/niri/` e `settings.json` → `~/.config/DankMaterialShell/`; cria stubs dos `include`s auto-gerados e valida o config do niri |
| Terminal | 1 | `terminal/install/1-kitty.sh` | Instala o **kitty** + **JetBrainsMono Nerd Font** |
| Terminal | 2 | `terminal/install/2-symlinks.sh` | Linka `kitty.conf` e `theme.conf` para `~/.config/kitty/` e valida a config |

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

### Shell / barra (via `pacman` + AUR)
- **dms-shell** (DankMaterialShell) — barra e UI Material 3 sobre quickshell; CLI `dms`
- **matugen** — cores dinâmicas (Material You)
- **wl-clipboard** + **cliphist** — histórico de clipboard
- **cava** — visualizador de áudio
- **qt6-multimedia** — sons do sistema
- **inter-font** — fonte de texto do DMS
- **ttf-material-symbols-variable-git** (AUR) — ícones do DMS

### Display manager (via `pacman`)
- **sddm** (+ `qt6-svg`, `qt6-declarative`) — tela de login; habilitado no boot

### Terminal (via `pacman`)
- **kitty** — terminal GPU com **animações de cursor** (rastro/trail, beam, piscada com easing, cursor oco ao desfocar). Tema **Catppuccin Mocha** como fallback, sobrescrito por cores **Material You dinâmicas** geradas pelo DMS (`dank-theme.conf`/`dank-tabs.conf` via matugen) que acompanham o wallpaper. Terminal padrão do niri (`Mod+T`)
- **JetBrainsMono Nerd Font** — fonte com ícones/ligaduras

---

## ⌨️ Atalhos do DMS (já no `config.kdl`)

| Atalho | Ação |
|--------|------|
| `Mod+Space` | App launcher (spotlight) |
| `Mod+Shift+Space` | Histórico de clipboard |
| `Mod+Shift+Escape` | Lista de processos |

> A barra sobe automaticamente no login via **`dms.service`** (serviço systemd de usuário, habilitado pelo `2-dms.sh`) — por isso o `spawn-at-startup` do DMS fica comentado no `config.kdl` (evita duplicar o shell). Settings do DMS: ícone de engrenagem na barra, ou `dms ipc call settings toggle`.

---

## 📁 Estrutura

```
dotfiles-cachyos/
├── setup.sh                 # orquestrador (menu de categorias)
├── lib/
│   └── install-helpers.sh   # helpers: pacman/AUR, symlink, serviços, log+resumo
└── desktop/
    ├── install/
    │   ├── 1-niri.sh         # instala niri + utilitários
    │   ├── 2-dms.sh          # instala DMS + habilita dms.service
    │   ├── 3-sddm.sh         # instala + habilita SDDM
    │   └── 4-symlinks.sh     # cria os symlinks dos configs abaixo
│   ├── niri/
│   │   └── config.kdl        # → ~/.config/niri/config.kdl
│   └── dms/
│       └── settings.json     # → ~/.config/DankMaterialShell/settings.json
└── terminal/
    ├── install/
    │   ├── 1-kitty.sh        # instala kitty + nerd font
    │   └── 2-symlinks.sh     # linka os configs do kitty
    └── kitty/
        ├── kitty.conf        # → ~/.config/kitty/kitty.conf
        └── theme.conf        # → ~/.config/kitty/theme.conf (fallback estático)
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
