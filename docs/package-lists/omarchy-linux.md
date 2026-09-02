# Omarchy Linux package list

This repo assumes an Omarchy-flavored Arch Linux base on any Linux host that
`.chezmoitemplates/omarchy-detect.tmpl` recognizes; no hostname list is
involved. That partial checks `OMARCHY_PATH`, which `omarchy dev link`
repoints, then `ID=omarchy` in `/etc/os-release`, then `/usr/share/omarchy`
(where Omarchy 4 packages the desktop) and `~/.local/share/omarchy` (the
Omarchy 3 clone). Only `OMARCHY_PATH` depends on the environment; the other
three do not, so an apply from a systemd unit, a cron job or
`ssh host chezmoi apply` resolves just as well as an interactive one.

## Omarchy-specific layer

These desktop files apply only on hosts where Omarchy is detected:

- `~/.config/hypr/bindings.lua`, `hyprland.lua`, `looknfeel.lua` and
  `monitors.lua`

The rest of `~/.config/hypr` belongs to the package. A file identical to the
shipped default only pins a stale copy, and Omarchy's update migrations rewrite
those files in place, which a later apply would revert. `/etc/skel/.config/hypr`
provisions them on a fresh account.

Omarchy's shell layer is not applied either; it is loaded at runtime from
whichever root the detection finds. `default/bash/env-bootstrap` is sourced by
`shell-env.sh`, the `default/bash/fns` helper functions by
`shell-interactive.sh`, and the `omarchy` dispatcher's completions by
`~/.bashrc`. See [../shell-startup.md](../shell-startup.md).

## System packages

Install these through Omarchy's package flow:

- `atuin`
- `bitwarden`
- `bitwarden-cli`
- `bun`
- `chezmoi`
- `cmake`
- `direnv`
- `dropbox`
- `dropbox-cli`
- `emacs-wayland`
- `firefox`
- `freecad`
- `keychain`
- `neovim`
- `ollama-cuda`
- `pinentry`
- `shellcheck`
- `tailscale`
- `vim`
- `visual-studio-code-bin`
- `zsh`

## AUR packages

- `bambustudio-nvidia-bin`
- `sccache-bin`
- `slack-desktop-wayland`

## Notes

- Omarchy installs a system `rust` package by default, but this repo expects `rustup`.
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
- This list is the source of truth for pacman and AUR packages. mise does not
  declare system packages on Linux; it owns only the portable CLI tools in
  `dot_config/mise/conf.d/20-linux.toml`, installed into `$HOME`.
- Theming is no longer wired to Omarchy. Every config names Rosé Pine Moon
  directly, so switching the Omarchy theme changes the desktop chrome but not
  the terminal, editors or btop.
