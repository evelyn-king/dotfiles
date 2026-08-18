# Omarchy configuration

[Omarchy](https://omarchy.org/) is an Arch derivative that ships its own
Hyprland setup and a Quickshell-based bar. It reports `ID=omarchy` with
`ID_LIKE=arch` in `/etc/os-release`, which is what `.chezmoiignore` keys on to
keep everything below off macOS, Ubuntu and WSL.

The goal here is that two Omarchy machines end up as identical as their
hardware allows: same theme, same font, same defaults, same applications. What
stops that from being a simple matter of copying `~/.config` is that Omarchy
keeps a fair amount of it elsewhere.

## Three kinds of setting, three mechanisms

**1. Plain files under `~/.config` and `~/.local/share`.** Tracked directly.

| Path | Carries |
| --- | --- |
| `~/.config/omarchy/shell.json` | Bar layout, widget order, idle and lock timings |
| `~/.config/omarchy/shell.toml` | Bar font size |
| `~/.config/omarchy/defaults/agent` | Default coding agent |
| `~/.config/xdg-terminals.list` | Default terminal (what `omarchy default terminal` writes) |
| `~/.config/mimeapps.list` | Default browser, plus the `mailto:`, `claude-cli:`, `slack:` and `codex:` handlers |
| `~/.config/hypr/monitors.lua` | Per-host display scaling, templated on hostname |
| `~/.local/share/applications/*.desktop` | Webapps and TUI launchers |
| `~/.local/share/icons/hicolor/256x256/apps/*.png` | The four webapp icons that are not package-owned |

**2. Settings whose source of truth is `~/.local/state` or fontconfig.**
Declared in `.chezmoidata/omarchy.yaml` and applied by
`run_onchange_after_omarchy-selections.sh.tmpl`, which calls Omarchy's own
setters:

| Setting | Why it is not a file |
| --- | --- |
| theme | `~/.local/state/omarchy/current/theme` is a rebuilt copy of the stock theme with user overlays merged in. Setting it also retints the terminals, tmux, btop, the browser, VSCode, Obsidian, GNOME and the keyboard. |
| background | A symlink into that same rebuilt directory, so the absolute path is not stable. Pinned by basename instead. |
| font | Canonically `~/.config/fontconfig/fonts.conf`, but setting it also rewrites the font line in every terminal's config. |
| default editor | Lives in `~/.local/state/omarchy/defaults/editor`. |

Each step compares before acting, so an apply on a machine that already matches
is silent. That matters: applying a theme restarts the shell and animates a
background transition.

**3. Packages.** Declared in the same data file, installed by
`run_onchange_after_omarchy-packages.sh.tmpl` through `omarchy pkg add` and
`omarchy pkg aur add`.

Scoped to *chosen applications*. Omarchy's own baseline
(`/usr/share/omarchy/install/omarchy-*.packages`) is present on every install
already, and the hardware-driven half of a machine's delta — `intel-ucode`,
`lib32-vulkan-intel`, `ollama-cuda`, `supergfxctl`, `fprintd`, `libfprint`,
`efibootmgr`, `mkinitcpio`, `usbutils` — belongs to the laptop, not to the
setup.

`omarchy pkg add` elevates on its own, so an install can prompt for a password.
When stdin is not a terminal the script reports what is missing and stops
rather than hanging a non-interactive apply.

To recompute the delta on a machine:

```sh
comm -23 <(pacman -Qqe | sort) \
         <(cat /usr/share/omarchy/install/omarchy-*.packages |
             grep -Ev '^\s*(#|$)' | sort -u)
```

## What is deliberately not tracked

Omarchy installs its stock configs into `~/.config` at first run, so nearly
everything there is a copy of `/usr/share/omarchy/config/`. Tracking those
copies would freeze this repo against whatever version was current at the time
and fight every `omarchy update`. Only files that diverge are tracked.

To see what has diverged:

```sh
cd /usr/share/omarchy/config &&
  for f in $(find . -type f | sed 's|^\./||'); do
    diff -q "$f" "$HOME/.config/$f" >/dev/null 2>&1 || echo "$f"
  done
```

Specific exclusions:

- **`~/.config/hypr/*.lua` other than `monitors.lua`** — all stock. Omarchy
  loads its defaults from `/usr/share/omarchy/default/hypr/` and then `require`s
  the user files on top, so an untouched `bindings.lua` does nothing the
  package would not do anyway. Add one here once it diverges.
- **`~/.config/omarchy/hooks/**/*.hook`** — Omarchy installs these itself, from
  `/usr/share/omarchy/install/user/first-run/`, via first-run and migrations
  (see `/usr/share/omarchy/migrations/1786549201.sh`). They are identical to
  their sources. Hooks that are genuinely hand-written belong here; install
  them with `omarchy hook install <event> <script>`.
- **`~/.config/omarchy/hooks/**/*.sample`** — stock examples, inert until
  renamed.
- **`~/.config/omarchy/branding/`** — `about.txt` and `screensaver.txt` are
  byte-identical copies of Omarchy's `icon.txt` and `logo.txt`. Track them if
  they are ever replaced with something personal.
- **`~/.config/hypr/envs.conf`** — written by `tensaku --wire-omarchy`, but
  nothing reads it: the Lua bootstrap only adds `.lua` files to `package.path`.
- **`~/.config/kitty/kitty.conf`** — differs from the default only in
  whitespace, because Omarchy's theming rewrites the `font_size` line.
- **`~/.local/share/applications/Stardew Valley.desktop`** and its
  `steam_icon_*` icons — generated by Steam when the game is installed, and
  regenerated on any machine that installs it.
- **`~/.local/state/omarchy/toggles/`** — `flags.lua` is a stock placeholder and
  `internal-monitor-scale` is per-panel.
- **Fonts** — every installed font package is already in Omarchy's baseline.
  Adding one means adding it to `packages.repo` and naming it in
  `omarchy.font`.
- **Channel and Plymouth theme** — `omarchy channel set` and
  `omarchy plymouth set` write under `/etc`, outside chezmoi's remit.

## Files Omarchy rewrites underneath chezmoi

Some tracked files are also written by Omarchy itself at runtime, so changing
them through the UI shows up as chezmoi drift:

- `monitors.lua` — `omarchy hyprland monitor scaling`, which is what the shell's
  monitor panel and `SUPER + /` drive, rewrites the two `local ... = <number>`
  lines in place.
- `shell.json` — `omarchy bar move` and friends rewrite the layout.
- `mimeapps.list` — `omarchy default browser` rewrites the handler lines.
- `xdg-terminals.list` — `omarchy default terminal` rewrites the whole file.

Make such a change stick with `chezmoi edit <path>`, or re-add the file after
tuning it live. This is the same tradeoff `~/.config/git/config` already makes
for `git config --global`.

## Adding to this

- **A new webapp**: create it with the Omarchy menu, then
  `chezmoi add ~/.local/share/applications/<Name>.desktop`. If it downloaded an
  icon, add `~/.local/share/icons/hicolor/256x256/apps/<icon>.png` too. Keep the
  executable bit — `omarchy-webapp-install` sets it, so the source file needs
  chezmoi's `executable_` prefix.
- **A new application**: add it to `packages.repo` or `packages.aur`.
- **A different theme or font**: edit `.chezmoidata/omarchy.yaml`. The script
  re-runs because its rendered content changed.

## Applying

Hyprland reloads `monitors.lua` on write; validate with:

```sh
hyprctl reload && hyprctl configerrors
```

`shell.json` and `shell.toml` hot-reload. `omarchy refresh shell` resets the
shell to package defaults (it backs up first) — after which `chezmoi apply`
puts this repo's version back.
