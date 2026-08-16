# dotfiles-chezmoi

Dotfiles managed directly with `chezmoi`.

## Structure

- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`
- the repo root contains the chezmoi source state for files under `$HOME`
- `.chezmoidata/` keeps template data
- top-level docs describe usage and repository conventions

## Apply

```bash
chezmoi apply
```

Use `chezmoi apply --dry-run --refresh-externals=never` to preview changes without updating pinned externals.

`~/.config/chezmoi/chezmoi.toml` is rendered from `.chezmoi.toml.tmpl` at init time, not on every apply. After pulling a change to that template, run `chezmoi init` once so the generated config picks it up.

## Homebrew

On macOS, this repo now manages a global Homebrew bundle in `~/.Brewfile`.

```bash
chezmoi edit ~/.Brewfile
check-homebrew
sync-homebrew
```

`check-homebrew`, `sync-homebrew`, and `dump-homebrew` default `HOMEBREW_NO_AUTO_UPDATE=1` so the bundle workflow does not implicitly refresh Homebrew metadata. `sync-homebrew` also uses `brew bundle --no-upgrade` by default, so it converges on the tracked top-level packages without opportunistically upgrading everything already installed. Add `--cleanup` if you want undeclared top-level packages removed as well.

To seed the Brewfile from an existing Mac, run:

```bash
dump-homebrew --source-dir /path/to/this/repo
```

This is deterministic at the package-set level. Homebrew still resolves concrete formula and cask versions from the current state of its taps, so strict version pinning needs versioned formulae or a custom tap.

## Branches

- `main` contains the macOS chezmoi source tree at the repo root

## Shell

Shell startup is `~/.zshenv` (environment) and `~/.zshrc` (PATH plus interactive
setup). See `docs/shell-startup.md` for the split and why PATH is built in
`.zshrc`.

## Theming

Everything is gruvbox. Each config sets its own theme directly — ghostty,
btop, neovim, vim, and doom — with no shared theme data or indirection layer.
Re-introduce a selector here if a second theme ever earns its keep.

## Remote Jupyter

`~/.zshenv` exports `JUPYTER_BIND_HOST`, `JUPYTER_ENV_NAME`, and `JUPYTER_PORT`,
binding JupyterLab to `127.0.0.1:8888` inside the `jupyter` environment.

`jupyter-remote-lab` runs `jupyter lab` through `micromamba run -n jupyter` or
`conda run -n jupyter` by default, so the notebook server starts inside that
environment without depending on an interactive shell activation step.

Use `jupyter-remote-lab` on the remote host to start a headless lab instance:

```bash
jupyter-remote-lab --detach --dir ~/work/project
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
