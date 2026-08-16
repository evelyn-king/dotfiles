# macOS Package List

Apple Silicon macOS machines use Homebrew as the primary package manager.

## Manifest

The canonical manifest is [`dot_Brewfile`](../../dot_Brewfile), which renders to
`~/.Brewfile`. It is generated from installed state rather than hand-maintained:

```bash
dump-homebrew --source-dir .   # regenerate from what is installed
check-homebrew                 # report drift without changing anything
sync-homebrew                  # install what the manifest declares
```

`dump-homebrew` writes top-level packages only — formulae that are not
dependencies of other formulae, plus casks and taps.

## Coverage

56 formulae, 17 casks, 3 taps. Broadly:

- Shell and terminal: `starship`, `zoxide`, `direnv`, `atuin`-adjacent tooling,
  `tmux`, `zellij`, `superfile`
- Search and file tools: `ripgrep`, `fd`, `fzf`, `bat`, `eza`, `dust`, `duf`,
  `jq`, `ast-grep`, `tealdeer`
- Git: `git`, `git-lfs`, `git-delta`, `git-filter-repo`, `lazygit`
- Languages and runtimes: `go`, `node`, `bun`, `lua-language-server`,
  `luarocks`, `micromamba`, `pixi`
- Editors: `neovim`, `vim`, `helix`, `emacs-plus-app`
- Casks: `ghostty`, `obsidian`, `zed`, `zen`, `dropbox`, `freecad`, `zotero`,
  and others

## Notes

- CLI tooling comes from Homebrew. `.chezmoidata/versions.yaml` pins only
  `keychain` — held back pending a check against 3.x — plus the tmux and vim
  plugins, which Homebrew does not package.
- The repo also keeps tool bootstraps for Doom Emacs and Rust.
- `luajit` and `tree-sitter` are installed but omitted from the manifest: they
  are dependencies of `neovim`, so Homebrew pulls them in automatically.
