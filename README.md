# Dotfiles

[Chezmoi](https://www.chezmoi.io/)-managed dotfiles for a shared Linux/macOS setup.

## Scope

- One repo handles both platforms through chezmoi templates and conditionals.
- Linux keeps the Omarchy/Hyprland layer, but only on hosts `gimli` and `maxwell`.
- macOS ignores the Omarchy desktop layer and uses Homebrew for package installation.

## Repository Structure

```text
.chezmoiexternal.toml.tmpl     # OS-aware external tool bootstraps
dot_bashrc                     # Bash configuration
dot_profile                    # POSIX login shell entrypoint
dot_zprofile / dot_zshrc       # Zsh login + interactive configuration
dot_config/shell/              # Shared shell modules for bash/zsh
dot_config/hypr/               # Hyprland config, Linux-only on selected hosts
dot_config/nvim/               # Neovim
dot_config/doom/               # Doom Emacs config
dot_config/tmux/               # Tmux
dot_config/zellij/             # Zellij
dot_local/bin/                 # Helper scripts (sync-uv, sync-bun, env)
dot_cargo/ / dot_rustup/       # Rust user config
run_once_before_install-*.sh   # One-time install hooks (Homebrew, rustup, etc.)
run_onchange_after_*.sh.tmpl   # Re-sync hooks for managed tooling
```

## Package Manifests

- [Omarchy Linux package list](docs/package-lists/omarchy-linux.md)
- [macOS package list](docs/package-lists/macos.md)
- [Homebrew Brewfile](Brewfile)

## Setup Notes

### Linux

1. Install `chezmoi`.
2. Initialize the repo with `chezmoi init <repo>`.
3. Apply it with `chezmoi apply`.
4. On Omarchy hosts, remove the system `rust` package first so `rustup` can own the user toolchain.

### macOS

1. Initialize the repo with `chezmoi init <repo>`.
2. Apply it with `chezmoi apply`.
3. The one-time Homebrew install hook will install Homebrew if it is missing.
4. Install packages from [`Brewfile`](Brewfile) when you want the full baseline.

## Notes

- The shell config is shared between `bash` and `zsh`, with `zsh` as the primary interactive shell.
- Rust now uses machine defaults instead of a Linux-specific default target.
- Tooling sync hooks remain command-guarded, so partial setups degrade cleanly.
