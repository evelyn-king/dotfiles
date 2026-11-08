# dotfiles

Dotfiles managed directly with `chezmoi`.

## Structure

- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`
- the repo root contains the chezmoi source state for files under `$HOME`
- `.chezmoidata/` keeps template data
- `.chezmoitemplates/` keeps bodies shared between several rendered files
- `docs/` and the top-level Markdown describe usage and repository conventions

## Supported platforms

Apple Silicon macOS, Omarchy 4 on x86_64 and aarch64 (Asahi) Linux, and Ubuntu
26.04 on x86_64 headless development hosts. Native Windows lives on the separate `windows` branch.

## Cold start

[docs/cold-start.md](docs/cold-start.md) takes a fresh supported host from
platform prerequisites through source initialization, activation, the repeated
applies, the manual service setup, and the final checks. It ends with the
workflows that have not been validated yet.

## Apply

```bash
chezmoi apply
```

`chezmoi apply --dry-run --refresh-externals=never` previews changes without
updating pinned externals. On an empty cache it still downloads them; see
[cold start](docs/cold-start.md).

Run `dotfiles-doctor` after setup or when troubleshooting tool ownership. It
reports duplicate tools, unused mise versions, and macOS system drift without
installing or removing anything. Routine applies print a reminder instead of
running those checks. The doctor reads the current lock from the source tree
and prints progress, successful results, warnings, and skipped checks.

chezmoi renders `~/.config/chezmoi/chezmoi.toml` from `.chezmoi.toml.tmpl` at
init time, not on every apply. After pulling a change to that template, run
`chezmoi init` once so the generated config picks it up.

## Packages

Package ownership depends on the host.

| Host | System packages | GUI apps | Runtimes and CLI tools |
| --- | --- | --- | --- |
| Apple Silicon macOS | Homebrew, declared in `homebrew/Brewfile` | Homebrew casks and App Store apps | mise |
| Omarchy 4 x86_64 / aarch64 | pacman and the AUR, via Omarchy | Omarchy | mise |
| Ubuntu 26.04 x86_64 | APT, via mise bootstrap | Headless | mise |

mise installs the shared versioned tools on every supported host. Linux apply
hooks also restore missing native packages without removing packages installed
by hand. See [macOS packages](docs/package-lists/macos.md),
[Omarchy packages](docs/package-lists/omarchy-linux.md), and
[Ubuntu packages](docs/package-lists/ubuntu-linux.md) for native package
ownership, and [mise tools](docs/package-lists/mise.md) for versioned tools.

### mise

Runtimes and global CLI tools are declared in plain TOML under
[`dot_config/mise/conf.d/`](dot_config/mise/conf.d/) and resolved by
`dot_config/mise/mise.lock`, which stays in the source tree. Most versions are
pinned. The coding agents, `gh` and `usage` float at `latest`, and Rust tracks
`stable`. Run `mup` to move the floating tools. It refreshes the lock for every
supported platform and installs from it; review and commit the lock change. The
mise binary itself is pinned in `.chezmoidata/versions.yaml`.

[docs/package-lists/mise.md](docs/package-lists/mise.md) covers the lock, the
release cooldown, the overlap with Omarchy packages and how to update mise.

## Shell

zsh and bash share environment, PATH and interactive setup bodies from
`.chezmoitemplates/shell-*.sh`. The rendered startup files stay flat and
self-contained, with nothing sourced from the source tree at runtime.

PATH is built twice, on purpose, and the order is load-bearing. See
[docs/shell-startup.md](docs/shell-startup.md).

One per-machine escape hatch is sourced after the shared environment defaults:
`~/.config/shell/extras.sh`, untracked and hand-written. Its exported values
also reach remote commands whose shell reads a managed startup file. Create it
with private permissions and keep long-lived credentials out of shell startup.
See [docs/shell-startup.md](docs/shell-startup.md#per-machine-overrides) for
the local-secret procedure.

## Editors

Neovim runs LazyVim; Vim runs a short `.vimrc` plus six pinned pack plugins.
They share one keymap as far as plain Vim reaches. Neovim is the reference, and
`dot_vim/plugin/keymaps.vim` mirrors LazyVim's defaults, so changing a binding
means changing both files. See [docs/keybindings.md](docs/keybindings.md).

Neovim plugin revisions float between hosts. lazy.nvim owns the generated
`lazy-lock.json`, the repo keeps it untracked, and installations can therefore
sit on different plugin revisions.

## Theming

Everything is [Gruvbox](https://github.com/morhetz/gruvbox), dark by default.
Each config names the theme directly. There is no shared theme data and no
indirection layer.

Ghostty, bat, Zellij, Herdr, superfile and Zed ship Gruvbox themes.
Neovim pulls `gruvbox.nvim`, while Vim uses a pinned chezmoi external from
`.chezmoidata/versions.yaml`.

btop and atuin use the repo-managed theme files under each tool's `themes/`
directory.

tmux and starship stay on ANSI color names rather than hex, so they inherit
whatever Ghostty is set to and never drift from it. Claude Code stays on `auto`,
and OpenCode's TUI stays on `system` in its separate `tui.json`.

Omarchy's theme switcher changes the desktop chrome it owns and nothing in this
repo.

The palette, for hand-editing a theme file:

| Token | Hex | | Token | Hex |
| --- | --- | --- | --- | --- |
| background | `#282828` | | red | `#cc241d` |
| background soft | `#32302f` | | orange | `#d65d0e` |
| background 1 | `#3c3836` | | yellow | `#d79921` |
| foreground | `#ebdbb2` | | green | `#98971a` |
| foreground 4 | `#a89984` | | aqua | `#689d6a` |
| foreground 3 | `#bdae93` | | blue | `#458588` |
| foreground 2 | `#d5c4a1` | | purple | `#b16286` |

## Agent git safety

Claude Code, Gemini CLI and opencode use advisory hooks for common unsafe Git
commands. The hooks block direct forms of commit amendment, hard reset, rebase,
force push, broad `git add`, protected-branch pushes, and PR merges.

These hooks are guardrails, not a security boundary. Shell wrappers, nested
interpreters, Git aliases, and commands that change directory before running
Git can bypass the matcher, and hook errors fail open in some adapters. Keep
remote branch protection enabled and review agent commands before execution.

The rules live in `.chezmoitemplates/git-rewrite-policy.py`; each hook is a thin
adapter for its tool's input and block protocol. Edit the shared policy, not the
adapters. The tests record both blocked commands and known advisory limits.

## Branches

- `main` contains the macOS/Linux chezmoi source tree at the repo root
- native Windows history lives on the separate `windows` branch

## Remote Jupyter

`jupyter-remote-lab` starts a headless JupyterLab inside the managed `jupyter`
environment, bound to localhost for an SSH tunnel.
[docs/jupyter.md](docs/jupyter.md) covers building the environments, launching
and tokens.
