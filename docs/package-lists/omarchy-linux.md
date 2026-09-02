# Omarchy Linux Package List

This repo assumes an Omarchy-flavored Arch Linux base on any Linux host where
`~/.local/share/omarchy` exists. That directory is what `.chezmoiignore.tmpl`
detects; no hostname list is involved. Set `OMARCHY_PATH` to override it.

## Omarchy-specific layer

These desktop files apply only on hosts where Omarchy is detected:

- `~/.config/hypr/*`
- Omarchy helper functions under `~/.local/share/omarchy`

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

## AUR packages

- `bambustudio-nvidia-bin`
- `sccache-bin`
- `slack-desktop-wayland`

## Notes

- Omarchy installs a system `rust` package by default, but this repo expects `rustup`.
- Web apps and Omarchy desktop defaults are intentionally documented outside the package list.
- This list is the source of truth for pacman and AUR packages. mise does not
  declare system packages on Linux; it owns only the portable CLI tools in
  `dot_config/mise/conf.d/20-linux.toml`, installed into `$HOME`.
- Theming is no longer wired to Omarchy. Every config names Rose Pine Moon
  directly, so switching the Omarchy theme changes the desktop chrome but not
  the terminal, editors or btop.
