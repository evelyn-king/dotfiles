# dotfiles

Dotfiles managed directly with `chezmoi`.

## Structure

- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`
- the repo root contains the chezmoi source state for files under `$HOME`
- `.chezmoidata/` keeps template data
- `.chezmoitemplates/` keeps bodies shared between several rendered files
- `docs/` and the top-level Markdown describe usage and repository conventions

## Cold start

Use [docs/cold-start.md](docs/cold-start.md) for a new Apple Silicon Mac or
Omarchy host. It starts with platform prerequisites and source initialization,
then covers activation, repeated applies, login or reboot, manual service setup,
and final verification.

## Apply

```bash
chezmoi apply
```

Use `chezmoi apply --dry-run --refresh-externals=never` to preview changes
without updating pinned externals.

`--refresh-externals=never` prevents refreshes of bodies already in chezmoi's
cache. It does not make a cold-cache run offline. The first dry run or apply
still downloads the six commit-pinned Vim plugin archives before writing any
destination files. Run that first command with network access, or copy a
populated cache from a trusted machine. The archive URLs are commit-pinned, but
the repo intentionally relies on HTTPS and GitHub's commit archive endpoint
instead of carrying checksums for their response bodies.

`~/.config/chezmoi/chezmoi.toml` is rendered from `.chezmoi.toml.tmpl` at init
time, not on every apply. After pulling a change to that template, run
`chezmoi init` once so the generated config picks it up.

## Packages

Package ownership depends on the host.

| Host | System packages | GUI apps | Runtimes and CLI tools |
| --- | --- | --- | --- |
| macOS | nix-darwin | Homebrew casks, declared in the flake | mise |
| Omarchy Linux | pacman and the AUR, via Omarchy | Omarchy | mise |

mise is the only package manager this repo drives on both platforms. On
Omarchy, an additive apply hook also restores missing system packages without
removing packages installed by hand. See
[docs/package-lists/macos.md](docs/package-lists/macos.md) and
[docs/package-lists/omarchy-linux.md](docs/package-lists/omarchy-linux.md) for
system packages, and [docs/package-lists/mise.md](docs/package-lists/mise.md)
for the runtimes and CLI tools managed by mise.

### mise

Language runtimes and global CLI tools are declared in
[`dot_config/mise/conf.d/10-dotfiles.toml`](dot_config/mise/conf.d/10-dotfiles.toml).
The file lives under `conf.d` rather than at `~/.config/mise/config.toml` so
repo-managed tools stay separate from mise's interactive global state. This
repo removes `~/.config/mise/config.toml`; declare every global tool in
`10-dotfiles.toml`. Omarchy owns Linux system CLI packages; Nix owns their
macOS counterparts.

`run_onchange_after_mise-install.sh.tmpl` installs them, and re-runs whenever
the file changes, so adding a tool is a one-line edit plus `chezmoi apply`.

Most versions are pinned exactly. Rust tracks the stable release channel; the
coding agents, `gh` and `usage` float at `latest` on purpose. mise holds new
releases for a day before it will resolve them; the coding agents opt out of
that cooldown in `10-dotfiles.toml`. `mise upgrade` skips global config, so
`mup` is what moves them:

```bash
mup
```

On macOS `mup` refreshes the untracked global lock under `~/.config/mise` and
installs the resolved versions. On Linux it refreshes the committed
`dot_config/mise/mise.lock` for `linux-x64` and installs with locked
resolution; review and commit the lockfile change afterwards. Rust is the one
channel-based exception: its lock entry remains `stable`, and rustup resolves
that channel when mise installs or updates it.

Like `nix/flake.lock`, that lock is repo content rather than a home file. mise
rewrites a lock in place whenever it installs, so an applied second copy under
`~/.config/mise` would diverge from the source tree after every install and
leave `chezmoi status` permanently dirty. The source tree holds the only copy,
and `mup` and the install script both reach it by setting `MISE_CONFIG_DIR`.
The applied `conf.d` files still drive the interactive shell's own tool
resolution.

Update the mise binary itself separately:

```bash
mise self-update
```

## Shell

zsh and bash share environment, PATH and interactive setup bodies from
`.chezmoitemplates/shell-*.sh`. The rendered startup files stay flat and
self-contained, with no shared body sourced at runtime.

PATH is built twice, on purpose, and the order is load-bearing. See
[docs/shell-startup.md](docs/shell-startup.md).

One per-machine escape hatch is sourced near the end of interactive startup:
`~/.config/shell/extras.sh`, untracked and hand-written. Create it with private
permissions and keep long-lived credentials out of shell startup. See
[docs/shell-startup.md](docs/shell-startup.md#per-machine-overrides) for the
local-secret procedure.

## Editors

Neovim runs LazyVim; Vim runs a short `.vimrc` plus six pinned pack plugins.
They share one keymap as far as plain Vim reaches: Neovim is the reference, and
`dot_vim/plugin/keymaps.vim` mirrors LazyVim's defaults. Changing a binding
means changing both files. See [docs/keybindings.md](docs/keybindings.md).

## Theming

Everything is [Gruvbox](https://github.com/morhetz/gruvbox), dark by default. Each
config sets its own theme directly, with no shared theme data or indirection
layer. Add a selector back if a second theme ever earns its keep.

Ghostty, Doom, bat, Zellij, Herdr, superfile and Zed ship Gruvbox themes.
Neovim pulls `gruvbox.nvim`, while Vim uses a pinned chezmoi external from
`.chezmoidata/versions.yaml`.

btop and atuin use the repo-managed theme files under each tool's `themes/`
directory.

tmux and starship deliberately stay on ANSI color names rather than hex, so
they inherit whatever Ghostty is set to and never drift from it. Claude Code
and opencode stay on `auto`/`system`.

Omarchy's own theme switching still themes the desktop chrome it owns, but no
longer drives anything in this repo.

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
Git can bypass the matcher. Hook errors also fail open in some adapters. Keep
remote branch protection enabled and review agent commands before execution.

The rules live in `.chezmoitemplates/git-rewrite-policy.py`; each hook is a thin
adapter for its tool's input and block protocol. Edit the shared policy, not the
adapters. The tests record both blocked commands and known advisory limits.

## Branches

- `main` contains the macOS/Linux chezmoi source tree at the repo root
- native Windows history lives on the separate `windows` branch

## Remote Jupyter

Shell startup exports `JUPYTER_BIND_HOST`, `JUPYTER_ENV_NAME` and
`JUPYTER_PORT`, binding JupyterLab to `127.0.0.1:8888` inside the `jupyter`
environment. Override any of them per machine in `~/.config/shell/extras.sh`.

`jupyter-remote-lab` runs `jupyter lab` through `micromamba run -n jupyter` or
`conda run -n jupyter` by default, so the notebook server starts inside that
environment without depending on an interactive shell activation step.

Create the managed environments before first use. This remains an explicit
step until the environment installer can replace an existing environment
without deleting the working copy first:

```bash
install-micromamba-env \
  ~/local-codex/environments/jupyter_environment.yml \
  ~/local-codex/environments/analysis_environment.yml
jupyter kernelspec list
```

Use `jupyter-remote-lab` on the remote host to start a headless lab instance:

```bash
jupyter-remote-lab --detach --dir ~/local-projects/project
```

Then create the SSH tunnel from your local machine with the exact port the
launcher printed, for example:

```bash
ssh -N -L 8888:127.0.0.1:8888 <ssh-host>
```

The launcher writes its last runtime metadata to
`${JUPYTER_REMOTE_ENV_FILE:-~/.local/state/jupyter-remote/current.env}`. Run
`jupyter_remote_load_env` in a shell if you want that runtime state loaded back
into your current environment after launching with overrides like `--port`.

For a custom token, put the token in a mode-0600 file and pass its path with
`--token-file`. The launcher copies it into its mode-0700 state directory and
passes only the file path to Jupyter. After stopping the server, remove the
token file named by `JUPYTER_REMOTE_TOKEN_FILE` and any old logs that contain
tokenized startup URLs.
