# macOS Package List

Apple Silicon macOS machines use Homebrew as the primary package manager.

## Manifest

The canonical package manifest is [`Brewfile`](../../Brewfile).

To install from it later:

```bash
brew bundle --file Brewfile
```

## Coverage

The manifest currently includes:

- CLI tools such as `atuin`, `bitwarden-cli`, `bun`, `chezmoi`, `cmake`, `direnv`, `keychain`, `neovim`, `pinentry`, `shellcheck`, and `vim`
- GUI apps such as `1password`, `Aerospace`, `Raycast`, `Ghostty`, `Dropbox`, `FreeCAD`, `OBS`, `Obsidian`, `Tailscale`, `Zed`, `Zen`, and `Zotero`

## Notes

- Hyprland and Omarchy desktop config are not applied on macOS.
- The repo also keeps cross-platform tool bootstraps for things like `uv`, `micromamba`, Doom Emacs, and Rust.
