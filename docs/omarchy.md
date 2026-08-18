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
| `~/.config/zed/settings.json` | Zed preferences (`vim_mode`), kept at mode 0600 as Zed writes it |

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

**3. Packages, fonts and editors.** Declared in the same data file, installed
by `run_onchange_after_omarchy-packages.sh.tmpl`.

`packages.repo`, `packages.fonts` and `packages.aur` go through `omarchy pkg
add` and `omarchy pkg aur add`. Fonts are split out only because that list
grows on its own; they install identically. Note that this is *not*
`omarchy install font`, which installs a font and immediately switches to it —
making a font available and choosing it are separate decisions, and the choice
is `omarchy.font`.

`editors` is a map of `omarchy install editor <key>` to the package whose
presence proves that editor is installed. Those get the full installer rather
than a package add, because each does post-install work a bare `pacman -S`
skips: `omazed setup` wires Zed's theme to Omarchy's, and the VSCode installer
writes `~/.vscode/argv.json` so credentials go to gnome-libsecret. The sentinel
package is what stops this re-running every apply, and it is not always the
key — `omarchy install editor zed` installs `zed` and `omazed`, and emacs
installs as `omarchy-emacs`. Editors are installed last, because each installer
finishes by launching the editor it just set up.

Vim is not an editor entry: it has no Omarchy installer, so it is an ordinary
`packages.repo` line.

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
- **Editor configuration written by the Omarchy installers** —
  `~/.config/Code/User/settings.json` holds only the colour theme (rewritten by
  `omarchy-theme-set-vscode`) and `update.mode`, both reproduced by the
  installer. `~/.vscode/argv.json` carries a per-install `crash-reporter-id`
  and must not be copied between machines. All of `~/.config/emacs/` is
  package-managed: `omarchy.el` is a generated shim that loads the packaged
  implementation, and the rest are byte-identical copies of
  `/usr/share/omarchy-emacs/config/`.
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
- `zed/settings.json` — `omazed` rewrites the `theme` block on every theme
  change. The rest of the file is yours.

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
- **A new font**: add the package to `packages.fonts`. That only makes it
  available; to use it, set `omarchy.font` to the family name as
  `omarchy font list` spells it.
- **A new editor**: if `omarchy install editor <name>` exists for it, add it to
  `editors` with the package that proves it installed (check with
  `pacman -Qqe` after installing). Otherwise it is just a package.
- **A different theme or font**: edit `.chezmoidata/omarchy.yaml`. The script
  re-runs because its rendered content changed.

## Emacs: plain package, not omarchy-emacs

`packages.repo` carries `emacs-wayland`, not `omarchy-emacs`. That is a
deliberate choice, and worth recording because the Omarchy menu pushes the
other one.

`omarchy-emacs` provides two things that are genuinely non-trivial: an Emacs
theme regenerated from Omarchy's palette on every `omarchy theme set` (via
`~/.config/omarchy/themed/omarchy-colors.el.tpl`), and a font sync that reads
the *active terminal's* family and size, using pixel sizes on pgtk so that
`omarchy display text size` is not applied twice. It also adds filenotify
watchers for live reload and `theme-set.d`/`font-set.d` hook drop-ins.

It is not used here for two reasons:

1. **Directory ownership.** `omarchy-emacs-setup` writes `init.el`,
   `omarchy.el` and `themes/` into `~/.config/emacs`, which is where
   `run_onchange_after_clone-doom-emacs.sh.tmpl` puts Doom's checkout. Only one
   can own it. (That script already refuses a directory that is not a git
   checkout, so the collision is inert rather than destructive — but it means
   Doom would silently never install.)
2. **Conflicting opinions.** The integration ends with
   `(add-hook 'before-save-hook #'delete-trailing-whitespace)`, which overrides
   the `(whitespace +guess +trim)` module in `dot_config/doom/init.el` —
   ws-butler trims only the lines you touched, this trims the whole buffer. It
   also calls `(enable-theme 'omarchy)`, against
   `(setq doom-theme 'doom-gruvbox)` in `dot_config/doom/config.el`. The rest
   of it (`menu-bar-mode -1`, `server-start`, a bash `-lc` shell) is Doom's
   territory anyway.

The tradeoff accepted is that Emacs does not follow `omarchy theme set`
automatically; `doom-theme` is matched to the Omarchy theme by hand.

If that ever needs revisiting, note that the package has **no pacman install
scriptlet** — installing it writes nothing into `$HOME`. All of the above comes
from `omarchy-emacs-setup`, which only `omarchy install editor emacs` runs. The
implementation lives at `/usr/share/omarchy-emacs/config/omarchy.el` and can be
loaded from `~/.config/doom/config.el` directly, leaving `~/.config/emacs` to
Doom. Its hooks self-heal: the code runs `omarchy-emacs-sync-hooks` on startup
when the drop-in is missing.

## Applying

Hyprland reloads `monitors.lua` on write; validate with:

```sh
hyprctl reload && hyprctl configerrors
```

`shell.json` and `shell.toml` hot-reload. `omarchy refresh shell` resets the
shell to package defaults (it backs up first) — after which `chezmoi apply`
puts this repo's version back.
