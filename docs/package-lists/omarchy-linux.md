# Omarchy Linux package list

This repo supports Omarchy 4 on x86_64 Linux.
[`../../.chezmoidata/packages.yaml`](../../.chezmoidata/packages.yaml) is the
source of truth for the required pacman and AUR packages. Read that file for the
list. This page covers how the hooks treat it and which desktop files the repo
owns.

Detection is broader than the support policy. The
`.chezmoitemplates/omarchy-detect.tmpl` partial also recognizes the legacy
Omarchy 3 clone, so an older installation does not silently take the
non-Omarchy branch, though the package hooks still require the Omarchy 4
dispatcher. The partial checks `OMARCHY_PATH`, which `omarchy dev link`
repoints, then `ID=omarchy` in `/etc/os-release`, `/usr/share/omarchy`, and the
legacy `~/.local/share/omarchy` clone. Only `OMARCHY_PATH` depends on the
environment, so an apply from a systemd unit, a cron job or
`ssh host chezmoi apply` resolves just as well as an interactive one.

## Omarchy-specific layer

Chezmoi manages these desktop files only on hosts where it detects Omarchy:

- `~/.config/hypr/bindings.lua`, `hyprland.lua` and `looknfeel.lua`

Chezmoi creates `~/.config/hypr/monitors.lua` only when it is missing. The
hostname-specific template seeds a new machine, then Omarchy owns the file so
changes made with its monitor-scaling control survive later applies. Delete the
file before an apply to seed it again.

The single-window aspect limit is global. `looknfeel.lua` enables the golden
ratio limit when any enabled display is wider than that ratio and disables it
otherwise. It reevaluates the limit after config reloads and monitor changes, so
docking and undocking do not depend on the hostname.

The rest of `~/.config/hypr` belongs to the package. A file identical to the
shipped default only pins a stale copy, and Omarchy's update migrations rewrite
those files in place, which a later apply would revert. `/etc/skel/.config/hypr`
provisions them on a fresh account.

Omarchy's shell layer is not applied either. It is loaded at runtime from
whichever root the detection finds. `shell-env.sh` sources
`default/bash/env-bootstrap`, `shell-interactive.sh` sources the
`default/bash/fns` helper functions for Bash only, and `~/.bashrc` loads the
`omarchy` dispatcher's completions. zsh receives a native port of `tdl` rather
than the full Bash helper set. See [../shell-startup.md](../shell-startup.md).

## System packages

Every `chezmoi apply` asks Omarchy to restore missing entries from the manifest.
The hooks are additive. They never remove unlisted packages, so packages
installed by hand stay installed.

Removing an entry from the manifest does not uninstall it. Remove that package
by hand if it is no longer wanted. A no-op apply does not prompt for sudo;
`omarchy pkg add` asks only when it finds a missing pacman package.

Keep packages Omarchy can install through pacman under `pacman`, including
packages from Omarchy's own repository. Put packages that need `yay` under
`aur`. The required pacman hook runs before mise setup. The AUR hook runs last,
so a failed optional package does not stop mise or local project trust from
being configured. Both hooks skip package restoration with a warning when the
Omarchy 4 dispatcher is unavailable.

Three rules constrain what goes in the manifest:

- Stock Omarchy owns the `tldr` command through its `tldr` package. Do not add
  `tealdeer`; the two packages conflict.
- mise owns Rust and installs rustup with the stable toolchain. Do not add a
  system `rust` or `rustup` package. The same goes for Pixi, which
  [mise](mise.md) owns on both platforms.
- `zsh` has to stay in the manifest. It is not part of a stock Omarchy install,
  and this repo is zsh-first: `~/.bashrc` hands off to zsh whenever it is
  present. Leave the package out and every login lands in the bash fallback.

Fonts are the one place where the two platforms differ on purpose. Ghostty's
font chain names `JetBrainsMono Nerd Font`, which Omarchy already ships, so the
manifest does not list it. The preferred CaskaydiaCove face has no Omarchy
package and is macOS only, from `nix/flake.nix`.

Web apps and Omarchy desktop defaults are not tracked here. Omarchy manages
them. Theming is not wired to Omarchy either. Every config names Gruvbox
directly, so switching the Omarchy theme changes the desktop chrome and leaves
the terminal, editors and btop alone.

## Post-apply services

The package hook installs the Tailscale and Dropbox packages, but it does not do
account setup. Run Omarchy's service installers from an interactive desktop
session after the apply:

```bash
omarchy install service tailscale
omarchy install service dropbox
```

The Tailscale installer uses elevated privileges to enable `tailscaled`, opens
the browser login, grants the local user operator access, enables Taildrop
receive, and adds the bar plugin. Review the tailnet's DNS and advertised routes
before accepting them. Verify the result with:

```bash
systemctl is-enabled tailscaled
tailscale status
tailscale debug prefs
```

The Dropbox installer adds its service dependencies, starts the daemon, and adds
the bar plugin. Finish the account login in the browser, then verify it:

```bash
dropbox-cli status
```

The shared manifest does not manage Ollama. Its CPU, NVIDIA, AMD and Vulkan
packages are per-machine choices, and most hosts do not need one. On a host that
does, choose the package and model locally, then verify the service:

```bash
ollama_package=ollama # or ollama-cuda, ollama-rocm, or ollama-vulkan
omarchy pkg add "$ollama_package"
sudo systemctl enable --now ollama
ollama pull <chosen-model>
systemctl is-active ollama
ollama list
```

The package hook is additive, so removing Ollama from the manifest does not
uninstall it from a machine that already has it.

## Refreshing Hyprland config

`omarchy refresh hyprland` runs `omarchy-refresh-config` over all seven shipped
Hypr files. Three are managed by this repo and one is seeded only when missing:

| File | Owner |
| --- | --- |
| `hyprland.lua` | this repo |
| `bindings.lua` | this repo |
| `looknfeel.lua` | this repo |
| `monitors.lua` | seeded once by this repo, then yours and Omarchy's |
| `input.lua` | Omarchy |
| `autostart.lua` | Omarchy |
| `.luarc.json` | Omarchy |

Each refresh replaces the file with the packaged default. If an existing file
differs, it keeps a backup at `<name>.bak.<epoch>`; identical files leave no
backup. This overwrites the three managed files and the current monitor setup.
`omarchy refresh config hypr/<file>` on a single managed file does the same.
The full Hyprland refresh also resets the runtime toggle flags under
`~/.local/state/omarchy/toggles/hypr/`, which chezmoi does not restore.
`hyprsunset.conf` is a separate refresh target and is not touched by this command.

To restore the repo configuration after a refresh, run:

```bash
chezmoi apply
chezmoi status .config/hypr
hyprctl reload
hyprctl configerrors
```

That restores `hyprland.lua`, `bindings.lua` and `looknfeel.lua` only.
`monitors.lua` is a `create_` target, so chezmoi writes it when it is missing
and leaves existing content alone. A refresh leaves the stock file in place and
`chezmoi apply` will not overwrite it. To recover your previous monitor layout,
copy the selected `monitors.lua.bak.<epoch>` backup back to `monitors.lua`.
To go back to the repo's seed instead, delete the file first:

```bash
rm ~/.config/hypr/monitors.lua
chezmoi apply
hyprctl reload
hyprctl configerrors
```

Check the restored scale against the `.bak` copy before deleting it, because any
scale chosen through Omarchy's monitor menu lives in that file rather than in
this repo.

Retained `.bak.<epoch>` files are unmanaged and remain in `~/.config/hypr/`.
Inspect them before removing selected backups by hand:

```bash
ls ~/.config/hypr/*.bak.*
```

Use `omarchy refresh config hypr/<file>` to refresh only `.luarc.json`,
`input.lua`, or `autostart.lua` when you want their packaged defaults without
overwriting the repo configuration or monitor layout.
