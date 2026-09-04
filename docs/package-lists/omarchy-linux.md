# Omarchy Linux package list

This repo supports Omarchy 4 on x86_64 Linux. Omarchy 3 and Linux arm64 are not
supported.

Detection is broader than the support policy. The
`.chezmoitemplates/omarchy-detect.tmpl` partial also recognizes the legacy
Omarchy 3 clone so an older installation does not silently take the
non-Omarchy branch. Package hooks still require the Omarchy 4 dispatcher. The
partial checks `OMARCHY_PATH`, which `omarchy dev link` repoints, then
`ID=omarchy` in `/etc/os-release`, `/usr/share/omarchy`, and the legacy
`~/.local/share/omarchy` clone. Only `OMARCHY_PATH` depends on the environment;
the other signals do not, so an apply from a systemd unit, a cron job or
`ssh host chezmoi apply` resolves just as well as an interactive one.

## Omarchy-specific layer

Chezmoi manages these desktop files only on hosts where Omarchy is detected:

- `~/.config/hypr/bindings.lua`, `hyprland.lua` and `looknfeel.lua`

Chezmoi creates `~/.config/hypr/monitors.lua` only when it is missing. The
hostname-specific template seeds a new machine, then Omarchy owns the file so
changes made with its monitor-scaling control survive later applies. Delete the
file before an apply to seed it again.

The single-window aspect limit is global. `looknfeel.lua` enables the golden
ratio limit when any enabled display is wider than that ratio and disables it
otherwise. It reevaluates the limit after config reloads and monitor changes,
so docking and undocking do not depend on the hostname.

The rest of `~/.config/hypr` belongs to the package. A file identical to the
shipped default only pins a stale copy, and Omarchy's update migrations rewrite
those files in place, which a later apply would revert. `/etc/skel/.config/hypr`
provisions them on a fresh account.

Omarchy's shell layer is not applied either; it is loaded at runtime from
whichever root the detection finds. `default/bash/env-bootstrap` is sourced by
`shell-env.sh`, the `default/bash/fns` helper functions by
`shell-interactive.sh` for Bash only, and the `omarchy` dispatcher's
completions by `~/.bashrc`. zsh receives a native port of `tdl`, not the full
Bash helper set. See [../shell-startup.md](../shell-startup.md).

## System packages

Required pacman and AUR packages are declared in
[`../../.chezmoidata/packages.yaml`](../../.chezmoidata/packages.yaml). Every
`chezmoi apply` asks Omarchy to restore missing entries. The hooks are
additive. They never remove unlisted packages, so manually installed packages
remain installed.

Removing an entry from the manifest does not uninstall it. Remove that package
manually if it is no longer wanted. A no-op apply does not prompt for sudo;
`omarchy pkg add` asks only when it finds a missing pacman package.

Pixi is supplied by [mise](mise.md) on both platforms. Existing pacman
installations must be removed manually after verifying `mise which pixi`;
the additive package hook does not uninstall them.

## AUR packages

Keep packages that Omarchy can install through pacman under `pacman`,
including packages from Omarchy's own repository. Put packages that require
`yay` under `aur`. The required pacman hook runs before mise setup. The AUR
hook runs last so a failed optional package does not prevent mise or local
project trust from being configured. Both hooks skip package restoration with
a warning when the Omarchy 4 dispatcher is unavailable.

## Post-apply services

The package hook installs the Tailscale and Dropbox packages, but it does not
perform account setup. Run Omarchy's service installers from an interactive
desktop session after the apply:

```bash
omarchy install service tailscale
omarchy install service dropbox
```

The Tailscale installer uses elevated privileges to enable `tailscaled`, opens
the browser login, grants the local user operator access, enables Taildrop
receive, and adds the bar plugin. Review the tailnet's DNS and advertised
routes before accepting them. Verify the result with:

```bash
systemctl is-enabled tailscaled
tailscale status
tailscale debug prefs
```

The Dropbox installer adds its service dependencies, starts the daemon, and
adds the bar plugin. Finish the account login in the browser, then verify it:

```bash
dropbox-cli status
```

The shared manifest does not manage Ollama. Its CPU, NVIDIA, AMD, and Vulkan
packages are per-machine choices, and most hosts do not need one. On a host
that does, choose the package and model locally, then verify the service:

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
Hypr files. This repo manages four of them:

| File | Owner |
| --- | --- |
| `hyprland.lua` | this repo |
| `bindings.lua` | this repo |
| `looknfeel.lua` | this repo |
| `monitors.lua` | seeded once by this repo, then yours and Omarchy's |
| `input.lua` | Omarchy |
| `autostart.lua` | Omarchy |
| `hyprsunset.conf` | Omarchy |

Each refresh copies the current file to `<name>.bak.<epoch>` and replaces it
with the packaged default, so the desktop reverts to stock for the managed
four. `omarchy refresh config hypr/<file>` on a single managed file does the
same.

**`chezmoi apply` is the recovery path, not `omarchy refresh hyprland`.** Run
it to restore the repo copies:

```bash
chezmoi apply
chezmoi status .config/hypr
hyprctl configerrors
```

That restores `hyprland.lua`, `bindings.lua` and `looknfeel.lua` only.
`monitors.lua` is a `create_` target, so chezmoi writes it when it is missing
and never touches it again. A refresh leaves the stock file in place and
`chezmoi apply` will not overwrite it. To go back to the repo's seed, delete
the file first:

```bash
rm ~/.config/hypr/monitors.lua
chezmoi apply
```

Check the restored scale against the `.bak` copy before deleting it, because
any scale chosen through Omarchy's monitor menu lives in that file rather than
in this repo.

The refresh leaves its `.bak.<epoch>` files in `~/.config/hypr/` indefinitely.
chezmoi does not manage them and nothing removes them, so delete them by hand:

```bash
ls ~/.config/hypr/*.bak.*
```

Refreshing the three unmanaged files is fine and is the intended way to pick up
Omarchy's updates to them.

## Notes

- Stock Omarchy owns the `tldr` command through its `tldr` package. Do not add
  `tealdeer` to the Omarchy manifest because the packages conflict. macOS also
  uses the stock `tldr` client through Nix.
- mise owns Rust and installs rustup with the stable toolchain. Do not install a
  separate system `rust` or `rustup` package.
- Ghostty's font chain names `JetBrainsMono Nerd Font` explicitly. Omarchy
  already ships it as `ttf-jetbrains-mono-nerd-basic`, so it is not listed
  above. The preferred CaskaydiaCove face has no Omarchy package and is macOS
  only, from `nix/flake.nix`.
- `zsh` is not part of a stock Omarchy install, and this repo is zsh-first:
  `~/.bashrc` hands off to zsh whenever it is present. Leave the package out
  and every login lands in the bash fallback.
- `~/.bashrc` replaces Omarchy's rather than extending it, so what Omarchy's
  copy provided is re-sourced piecemeal instead. See
  [../shell-startup.md](../shell-startup.md).
- Web apps and Omarchy desktop defaults are not tracked here. Omarchy manages
  them.
- `.chezmoidata/packages.yaml` is the source of truth for required pacman and
  AUR packages. mise owns only the shared language runtimes and global CLI
  tools in `dot_config/mise/conf.d/10-dotfiles.toml`.
- Theming is no longer wired to Omarchy. Every config names Gruvbox
  directly, so switching the Omarchy theme changes the desktop chrome but not
  the terminal, editors or btop.
