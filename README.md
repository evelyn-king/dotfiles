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

If you already have this repo initialized from the previous `home/` layout, run `chezmoi init` once after pulling so your generated config picks up the repo-root `sourceDir`.

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
- native Windows history lives on the separate `windows` branch

## Shell

Shell startup is `~/.zshenv` (environment) and `~/.zshrc` (PATH plus interactive
setup). See `docs/shell-startup.md` for the split and why PATH is built in
`.zshrc`.

## Theming

`.chezmoidata/theme.yaml` holds the active theme name; `dot_config/themes/`
holds one directory per theme. Change the name and run `chezmoi apply` to
re-theme ghostty, btop, and neovim. The active name is also rendered to
`~/.config/themes/current-theme` for consumers that resolve it at runtime.

## Encryption

Encrypted files use a single age key. See `docs/encryption.md` for key and
recipient wiring.

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
