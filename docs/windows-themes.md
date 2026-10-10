# Windows themes

Native Windows gets Omarchy's theme switching. `theme` in PowerShell is a port
of the `omarchy theme` commands, and it reads Omarchy's own theme format, so a
theme looks the same on both systems and any Omarchy theme repo installs here
unchanged.

```powershell
theme list                 # stock themes plus yours
theme current
theme set "Tokyo Night"    # "tokyo-night" works too
theme bg next              # cycle the current theme's wallpapers
theme install https://github.com/<owner>/omarchy-<name>-theme.git
theme remove <name>        # one you installed
```

## What a switch changes

| Target | How |
|---|---|
| Windows Terminal | Writes the palette as the `Omarchy` scheme into a JSON fragment under `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\Omarchy\`. The managed `settings.json` selects that scheme in `profiles.defaults`. |
| Everything in the terminal | Starship, PSReadLine, fzf, eza, lazygit and bat (`BAT_THEME=ansi`) use ANSI colours, so they follow the scheme. |
| Neovim | `lua/plugins/theme.lua` loads the theme's `neovim.lua`, or one rendered from Omarchy's template for themes without one. Takes effect in new Neovim sessions. |
| Windows | Dark or light mode from the theme's `mode`, the accent colour from `accent`, and the wallpaper. WebP wallpapers are converted to JPEG in `~/.cache/omarchy/backgrounds`. |
| VS Code | For themes with a `vscode.json`: installs the named extension and sets `workbench.colorTheme`. |

`theme` returns once the Windows Terminal and Neovim files are written. The
Windows and VS Code rows are applied a few seconds later by a hidden
background process, because the mode and accent change waits for every open
window to repaint. Pass `-Wait` to `set` or `refresh` to apply them before the
command returns, as the chezmoi refresh script does. Background failures are
logged to `~/.local/state/omarchy/theme-apply.log`. Hooks may run before the
background apply has finished.

To skip a target, create an empty file named `skip-windows-mode`,
`skip-windows-accent`, `skip-windows-wallpaper` or `skip-vscode-theme-changes`
in `~/.local/state/omarchy/toggles/`.

## Where things live

| Path | Owner | Contents |
|---|---|---|
| `~/.local/share/omarchy/themes/` | chezmoi external | Omarchy's stock themes, pinned by `omarchy.url` in `.chezmoidata/versions.yaml` |
| `~/.local/share/omarchy/default/themed/` | chezmoi external | Omarchy's colour templates; only `neovim.lua.tpl` and `btop.theme.tpl` are rendered |
| `~/.config/omarchy-windows/` | chezmoi | The switcher, `theme.ps1`, and Windows-only templates in `themed/` |
| `~/.config/omarchy/themes/<name>/` | you | Your themes, overlaid on a stock theme of the same name |
| `~/.config/omarchy/themed/*.tpl` | you | Your templates, used ahead of the ones above |
| `~/.config/omarchy/backgrounds/<name>/` | you | Extra wallpapers for a theme |
| `~/.config/omarchy/hooks/theme-set.d/*.ps1` | you | Run after each switch with the theme name as the first argument |
| `~/.local/state/omarchy/current/` | `theme` | The staged current theme, its name and wallpaper |

Templates use Omarchy's syntax: `{{ key }}` for any palette key, plus
`{{ key_strip }}`, `{{ key_rgb }}` and `{{ mix a b 30% }}`. Palette keys are
resolved with the same fallbacks as `omarchy-theme-color`. A theme that ships a
file with a template's output name overrides that template.

A theme installed from a git repo cannot supply `.lua` files, terminal configs
or `vscode.json`, since those run code. It gets the generated Neovim theme
instead, as on Omarchy.

## Applying and updating

`run_onchange_after_theme-refresh.ps1.tmpl` re-renders the current theme when
the switcher, its templates or the Omarchy pin change. On a machine with no
theme yet, it sets Gruvbox. To pick up new Omarchy themes, point `omarchy.url`
at a newer commit and run `chezmoi apply`.

A running Windows Terminal reloads when `theme` touches its `settings.json`. If
the colours don't change, open a new window. Accent changes can take a moment
to reach the taskbar.
