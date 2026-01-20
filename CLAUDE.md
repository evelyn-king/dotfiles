# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a dotfiles repository for *nix OSs using the [dotbot](https://github.com/anishathalye/dotbot) toolchain. It manages configuration files for shell, terminal, editors, and system utilities across Linux and macOS with platform-conditional linking.

## Installation and Commands

### Installing/Updating Dotfiles
```bash
./install
```
This script runs dotbot which:
1. Creates necessary directories
2. Evaluates platform conditionals (`if` directives) to link appropriate configs
3. Syncs and updates git submodules
4. Runs post-install shell commands

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

### Unified Configuration with Platform Conditionals

The repository uses a single `install.conf.yaml` with dotbot `if` conditionals for platform-specific behavior:

| Config | Method | Details |
|--------|--------|---------|
| **Git** | Native `[includeIf]` | Links `~/.gitconfig.platform` to macos/linux variant |
| **Starship** | Dotbot `if` conditional | Different prompt configs per platform |
| **Hyprland** | Dotbot `if` conditional | Linux-only (window manager) |

Platform detection uses `[ "$(uname)" = "Darwin" ]` for macOS and `[ "$(uname)" = "Linux" ]` for Linux.

### Directory Structure

- **`configs/`** - All dotfile configurations organized by tool
  - `configs/git/gitconfig` - Main git config with `[includeIf]` directive
  - `configs/git/gitconfig.macos` - macOS-specific (osxkeychain credential helper)
  - `configs/git/gitconfig.linux` - Linux-specific git settings
  - `configs/starship/starship.toml` - Linux starship config
  - `configs/starship/starship.toml.macos` - macOS starship config
  - `configs/hypr/` - Hyprland configs (Linux only)
- **`submodules/`** - Git submodules for:
  - `submodules/dotbot/` - The dotbot installation framework
  - `submodules/vim/*` - Vim plugins (everforest, fugitive, lightline, nerdcommenter, nerdtree, surround)
  - `submodules/tmux/tpm/` - Tmux Plugin Manager
- **`install.conf.yaml`** - Unified dotbot configuration with platform conditionals
- **`install`** - Main installation script

### Dotbot Configuration Pattern

The install YAML follows this structure:
1. **defaults** - Link behavior (create parent dirs, relink)
2. **clean** - Remove broken symlinks from home directory
3. **create** - Create necessary directories
4. **link** - Map source configs to destinations with `if` conditionals for platform-specific links
5. **shell** - Post-install commands (submodule sync, dotbins)

Key patterns:
- `~/.config/*` uses glob to link most configs with exclusions for special handling
- Platform-conditional links use `if: '[ "$(uname)" = "..." ]'` syntax
- Vim plugins from `submodules/vim/*` link to `~/.vim/pack/plugins/start/*`

### Configuration Tools Managed

- **Shell**: fish, starship (prompt)
- **Terminal multiplexers**: tmux, zellij
- **Editors**: vim, nvim, kak, zed
- **Terminal emulator**: wezterm
- **Window manager**: hypr (Hyprland, Linux only)
- **System utilities**: btop, thefuck
- **Development**: git, conda

## Adding New Configurations

When adding a new machine:
1. Run `./install` - unified config handles both platforms
2. For machine-specific monitors (Linux): Create `configs/hypr/monitors.${HOST}.conf`

When adding new tool configs:
1. Place config files in `configs/${TOOL}/`
2. Update `install.conf.yaml` to create symlinks
3. Use `if` conditionals for platform-specific configs

When adding platform-specific behavior:
1. Create variant files (e.g., `config.macos`, `config.linux`)
2. Add conditional links in `install.conf.yaml`
3. For git, prefer native `[includeIf]` directives
