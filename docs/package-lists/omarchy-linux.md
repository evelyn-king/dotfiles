# Omarchy Linux Package List

This repo assumes an Omarchy-flavored Arch Linux base only on hosts with the
`omarchy_desktop` feature enabled.

## Omarchy-specific layer

These machine-specific desktop files only apply on Linux hosts named `gimli` or `maxwell`:

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
