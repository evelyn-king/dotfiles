# dotfiles

Dotfiles managed directly with `chezmoi`.

## Structure

- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`
- the repo root contains the chezmoi source state for files under `$HOME`
- `.chezmoidata/` keeps template data
- `.chezmoitemplates/` keeps bodies shared between several rendered files
- `docs/` and the top-level Markdown describe usage and repository conventions

## Apply

```bash
chezmoi apply
```

Use `chezmoi apply --dry-run --refresh-externals=never` to preview changes
without updating pinned externals.

`~/.config/chezmoi/chezmoi.toml` is rendered from `.chezmoi.toml.tmpl` at init
time, not on every apply. After pulling a change to that template, run
`chezmoi init` once so the generated config picks it up.

## Packages

Package ownership depends on the host.

| Host | System packages | GUI apps | Runtimes and CLI tools |
| --- | --- | --- | --- |
| macOS | nix-darwin | Homebrew casks, declared in the flake | mise |
| Omarchy Linux | pacman and the AUR, via Omarchy | Omarchy | mise |

mise is the only package manager this repo drives on both. See
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

Two per-machine escape hatches are sourced near the end of interactive startup:
`~/.config/shell/secrets.sh` (tracked, age-encrypted) and
`~/.config/shell/extras.sh` (untracked, hand-written).

## Theming

Everything is [Rosé Pine Moon](https://rosepinetheme.com), dark only. Each
config sets its own theme directly, with no shared theme data or indirection
layer. Add a selector back if a second theme ever earns its keep.

Ghostty ships the theme itself, so that config just names it. Neovim, Vim and
Doom pull a plugin. The Vim colorscheme is a pinned chezmoi external in
`.chezmoidata/versions.yaml`, and Doom pins the community port in
`dot_config/doom/packages.el` because `doom-themes` has no Rosé Pine.

btop, atuin and Zellij ship no Rosé Pine, so the theme files under each tool's
`themes/` directory are repository content, hand-written from the palette. bat
is the same idea with one extra step. Its `.tmTheme` comes verbatim from
[rose-pine/tm-theme](https://github.com/rose-pine/tm-theme), and bat reads
themes only from a binary cache, so `run_onchange_after_build-bat-cache.sh.tmpl`
runs `bat cache --build` whenever the theme or bat config changes. Zed installs
the theme through `auto_install_extensions`.

tmux and starship deliberately stay on ANSI color names rather than hex, so
they inherit whatever Ghostty is set to and never drift from it. Claude Code
and opencode have no Rosé Pine option and stay on `auto`/`system`.

Omarchy's own theme switching still themes the desktop chrome it owns, but no
longer drives anything in this repo.

The palette, for hand-editing a theme file:

| Token | Hex | | Token | Hex |
| --- | --- | --- | --- | --- |
| base | `#232136` | | love | `#eb6f92` |
| surface | `#2a273f` | | gold | `#f6c177` |
| overlay | `#393552` | | rose | `#ea9a97` |
| muted | `#6e6a86` | | pine | `#3e8fb0` |
| subtle | `#908caa` | | foam | `#9ccfd8` |
| text | `#e0def4` | | iris | `#c4a7e7` |
| highlight low | `#2a283e` | | highlight med | `#44415a` |
| highlight high | `#56526e` | | | |

## Agent git safety

Claude Code, Gemini CLI and opencode all block history rewrites, broad staging,
protected-branch pushes and PR merges. The rules live once, in
`.chezmoitemplates/git-rewrite-policy.py`; each hook is a thin adapter that
translates its tool's input and block protocol. Edit the shared policy, not the
adapters.

`.chezmoitemplates/test_git_rewrite_policy.py` covers the policy:

```bash
python3 -m pytest .chezmoitemplates/test_git_rewrite_policy.py
```

## Encryption

One age key covers the encrypted files in this repo. See
[docs/encryption.md](docs/encryption.md).

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

Use `jupyter-remote-lab` on the remote host to start a headless lab instance:

```bash
jupyter-remote-lab --detach --dir ~/local-praxis/project
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
