# dotfiles-chezmoi

Dotfiles managed directly with `chezmoi`.

Targets macOS, Ubuntu, Arch, and Ubuntu under WSL. **You install the programs;
these configs adapt to whichever ones they find.** Nothing here installs a terminal, an editor or a
CLI tool — every config detects at runtime, so a missing tool costs you that
tool and not a broken shell. Use brew, apt, pacman or nix as the machine
prefers.

## Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/machinetype/portable/bootstrap.sh | bash
```

Installs the only two things chezmoi cannot bootstrap for itself — git and
chezmoi — then runs `chezmoi init --apply`. What is left over is a manual
checklist. See [`docs/bootstrap.md`](docs/bootstrap.md).

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

## Packages

Language runtimes and global CLI tools come from mise, declared in
[`dot_config/mise/config.toml`](dot_config/mise/config.toml). `chezmoi apply`
installs them; adding one is a one-line edit.

```bash
mise upgrade --bump    # move the pins, review the diff, commit
```

Pins are exact, so the set is reproducible and moves only when you update it.
That is the only thing this repo installs — everything else is yours, by
whatever means the machine prefers. If mise itself is absent the hook exits
quietly and you simply get no runtimes.

## Shell

zsh and bash are both first-class; zsh is the default. The bodies live in
`.chezmoitemplates/shell-{env,path,interactive}.sh` and are stitched into
`~/.zshrc` and `~/.bashrc` at apply time, so each rendered file is flat and
self-contained with no runtime source chain. See
[`docs/shell-startup.md`](docs/shell-startup.md) for the split, why PATH is
built in the interactive rc, and the ordering constraints.

## Theming

Everything is gruvbox. Each config sets its own theme directly — ghostty,
btop, neovim, vim, and doom — with no shared theme data or indirection layer.
Add a selector here if a second theme ever earns its keep.

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
