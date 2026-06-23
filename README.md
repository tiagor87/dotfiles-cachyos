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
| Desktop | 1 | `desktop/install/1-niri.sh` | Instala o **niri** + utilitários da sessão (alacritty, fuzzel, swaylock, swaybg, playerctl, brightnessctl, xwayland-satellite, portais XDG) e linka `config.kdl` em `~/.config/niri/` |
| Desktop | 2 | `desktop/install/2-dms.sh` | Instala o **DankMaterialShell** (`dms-shell`) + deps (matugen, wl-clipboard, cliphist, cava, qt6-multimedia, inter-font, ícones Material Symbols do AUR) |
| Desktop | 3 | `desktop/install/3-sddm.sh` | Instala e habilita o **SDDM** no boot; avisa se outro display manager já estiver ativo |

---

## 🧩 Stack instalado

### Compositor & sessão (via `pacman`)
- **niri** — compositor Wayland scrollable-tiling
- **alacritty** — terminal (`Mod+T`)
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

---

## ⌨️ Atalhos do DMS (já no `config.kdl`)

| Atalho | Ação |
|--------|------|
| `Mod+Space` | App launcher (spotlight) |
| `Mod+V` | Histórico de clipboard |
| `Mod+M` | Lista de processos |

> A barra sobe automaticamente no login via `spawn-at-startup "dms" "run"` no config do niri — **não** usamos `dms.service` (evita duplicar o shell). Settings do DMS: ícone de engrenagem na barra, ou `dms ipc call settings toggle`.

---

## 📁 Estrutura

```
dotfiles-cachyos/
├── setup.sh                 # orquestrador (menu de categorias)
├── lib/
│   └── install-helpers.sh   # helpers: pacman/AUR, symlink, serviços, log+resumo
└── desktop/
    ├── install/
    │   ├── 1-niri.sh
    │   ├── 2-dms.sh
    │   └── 3-sddm.sh
    └── niri/
        └── config.kdl        # config do niri (linkado p/ ~/.config/niri/)
```

---

## ➕ Adicionando uma categoria

1. Crie a pasta `<categoria>/install/` com scripts `N-*.sh`.
2. Cada script começa com `# nome.sh — descrição` (vira o título no pipeline) e faz `source "${DOTFILES_ROOT}/lib/install-helpers.sh"`.
3. Registre a categoria no array `CATEGORIES` do `setup.sh`.

---

## 📜 Licença

MIT — veja [LICENSE](LICENSE).
