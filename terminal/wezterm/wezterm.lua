-- wezterm.lua — WezTerm (CachyOS / niri)
--
-- Linkado para ~/.config/wezterm/wezterm.lua pelo terminal/install/2-symlinks.sh.
-- Baseado no config do repo dotfiles-windows, adaptado para Linux:
--  - shell padrão do sistema (zsh) em vez de pwsh;
--  - cores dinâmicas Material You do DMS (matugen) em vez de "Tokyo Night";
--  - equalize de panes via node, sem wrapper do PowerShell.

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ─── Fonte ───────────────────────────────────────────────────────────────────
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 11.5
config.line_height = 1.1
config.adjust_window_size_when_changing_font_size = false

-- ─── Cores ───────────────────────────────────────────────────────────────────
-- 1) fallback estático bonito (Catppuccin Mocha, embutido no WezTerm)...
config.color_scheme = "Catppuccin Mocha"
-- 2) ...sobrescrito pelas cores dinâmicas do DMS quando presentes (Material You).
--    O template matugen do DMS grava ~/.config/wezterm/colors/dank-theme.toml e
--    o watch abaixo faz o WezTerm recolorir junto com o wallpaper.
local dank_theme = wezterm.home_dir .. "/.config/wezterm/colors/dank-theme.toml"
wezterm.add_to_config_reload_watch_list(dank_theme)
local ok, scheme = pcall(wezterm.color.load_scheme, dank_theme)
if ok and scheme then
    config.colors = scheme
end

-- ─── Aparência da janela ─────────────────────────────────────────────────────
config.window_background_opacity = 0.92
config.window_decorations = "RESIZE" -- o niri desenha bordas/gaps; sem título
config.window_padding = { left = 12, right = 12, top = 12, bottom = 12 }
config.audible_bell = "Disabled"

-- ─── Abas ────────────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true

-- ─── Rolagem / performance ───────────────────────────────────────────────────
config.scrollback_lines = 20000

-- ─── Equalize de panes ───────────────────────────────────────────────────────
-- Distribui o tamanho dos panes da aba igualmente (Ctrl+Shift+E). O script é o
-- mesmo do repo-fonte; só o disparo muda (node direto + WEZTERM_PANE via env).
wezterm.on("equalize-panes", function(_, pane)
    local script = wezterm.home_dir .. "/.config/wezterm/equalize.js"
    wezterm.run_child_process({
        "env", "WEZTERM_PANE=" .. pane:pane_id(), "node", script,
    })
end)

-- ─── Atalhos ─────────────────────────────────────────────────────────────────
config.keys = {
    -- Abas
    { key = "t",   mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
    { key = "w",   mods = "CTRL",       action = wezterm.action.CloseCurrentTab({ confirm = false }) },
    { key = "Tab", mods = "CTRL",       action = wezterm.action.ActivateTabRelative(1) },
    { key = "Tab", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },

    -- Splits (panes)
    { key = "\\",  mods = "CTRL",       action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-",   mods = "CTRL",       action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

    -- Navegação entre panes (hjkl + setas)
    { key = "h",          mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "l",          mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "k",          mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "j",          mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "UpArrow",    mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "DownArrow",  mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },

    { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
    { key = "z", mods = "CTRL|SHIFT", action = wezterm.action.TogglePaneZoomState },
    { key = "e", mods = "CTRL|SHIFT", action = wezterm.action.EmitEvent("equalize-panes") },

    -- Clipboard / busca / reload
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
    { key = "f", mods = "CTRL|SHIFT", action = wezterm.action.Search("CurrentSelectionOrEmptyString") },
    { key = "r", mods = "CTRL|SHIFT", action = wezterm.action.ReloadConfiguration },

    -- Fonte
    { key = "0",     mods = "CTRL", action = wezterm.action.ResetFontSize },
    { key = "+",     mods = "CTRL", action = wezterm.action.IncreaseFontSize },
    { key = "=",     mods = "CTRL", action = wezterm.action.IncreaseFontSize },
    { key = "-",     mods = "CTRL|SHIFT", action = wezterm.action.DecreaseFontSize },

    -- Shift+Enter = "nova linha" (CSI u) p/ Claude Code / nvim / TUIs de agente.
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b[13;2u") },
}

return config
