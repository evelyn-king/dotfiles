# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a dotfiles repository for *nix OSs using the [dotbot](https://github.com/anishathalye/dotbot) toolchain. It manages configuration files for shell, terminal, editors, and system utilities across multiple machines with per-host customization support.

## Installation and Commands

### Installing/Updating Dotfiles
```bash
./install
```
This script:
1. Detects the hostname using `hostname -s`
2. Looks for a per-host config file: `install.${HOSTNAME}.yaml`
3. Falls back to `install.conf.yaml` if no host-specific config exists
4. Syncs and updates git submodules
5. Runs dotbot to create symlinks and execute shell commands

### Testing Without Making Changes
```bash
./install --dry-run
```

### Updating Submodules
```bash
git submodule sync --recursive
git submodule update --init --recursive --remote
```

## Architecture

### Per-Host Configuration System

The repository supports multiple machines with different configurations. Each machine can have its own install configuration file named `install.${HOSTNAME}.yaml` (e.g., `install.rabi.yaml`, `install.gimli.yaml`, `install.Lagrange.yaml`).

Host-specific configs allow:
- Different gitconfigs (e.g., `configs/git/gitconfig.rabi` vs `configs/git/gitconfig.gimli`)
- Machine-specific monitor setups (`configs/hypr/monitors.*.conf`)
- Custom autostart configurations (`configs/hypr/autostart.*.conf`)
- Different vim/editor configurations (`configs/vim/vimrc.*`)

### Directory Structure

- **`configs/`** - All dotfile configurations organized by tool (git, vim, tmux, hypr, nvim, fish, etc.)
- **`submodules/`** - Git submodules for:
  - `submodules/dotbot/` - The dotbot installation framework
  - `submodules/vim/*` - Vim plugins (everforest, fugitive, lightline, nerdcommenter, nerdtree, rose-pine, surround)
  - `submodules/tmux/tpm/` - Tmux Plugin Manager
- **`install.*.yaml`** - Dotbot configuration files (per-host and default)
- **`install`** - Main installation script with hostname detection

### Dotbot Configuration Pattern

The install YAML files follow this structure:
1. **defaults** - Link behavior (create parent dirs, relink)
2. **clean** - Remove broken symlinks from home directory
3. **create** - Create necessary directories (`~/.vim/pack/plugins/start`, `~/.tmux/plugins`, `~/local-*` workspaces)
4. **link** - Map source configs to home directory destinations using glob patterns
5. **shell** - Post-install commands (mainly submodule sync/update)

Key linking patterns:
- `~/.config/*` uses glob to link most configs from `configs/*` with specific exclusions
- Vim plugins from `submodules/vim/*` link to `~/.vim/pack/plugins/start/*`
- Some configs like tmux, vim, and hypr need explicit links outside `~/.config/`

### Configuration Tools Managed

- **Shell**: fish, starship (prompt)
- **Terminal multiplexers**: tmux, zellij
- **Editors**: vim, nvim, kak, zed
- **Terminal emulator**: wezterm
- **Window manager**: hypr (Hyprland)
- **System utilities**: btop, thefuck
- **Development**: git, conda

## Adding New Configurations

When adding a new machine:
1. Create `install.${HOSTNAME}.yaml` based on existing host configs
2. Add machine-specific config variants in relevant `configs/` subdirectories
3. Update the install YAML to reference the new host-specific configs

When adding new tool configs:
1. Place config files in `configs/${TOOL}/`
2. Update install YAML files to create the appropriate symlinks
3. Consider whether different hosts need different variants
