# Remote Jupyter

`jupyter-remote-lab` runs JupyterLab on a remote host through
`micromamba run -n jupyter` or `conda run -n jupyter`, so the server starts
inside the managed environment without activating it in a shell. Shell startup
exports `JUPYTER_BIND_HOST`, `JUPYTER_ENV_NAME` and `JUPYTER_PORT`, which bind
it to `127.0.0.1:8888` in the `jupyter` environment. Override any of them per
machine in `~/.config/shell/extras.sh`.

## Environments

Build the managed environments before first use, then check that both kernels
are registered:

```bash
install-micromamba-env \
  ~/local-codex/environments/jupyter_environment.yml \
  ~/local-codex/environments/analysis_environment.yml
micromamba run -n jupyter jupyter kernelspec list
```

The installer builds and smoke-tests a staging environment before it replaces
an existing one. It keeps the old environment and kernel until the replacement
and its kernel are both ready, and restores them if any step fails.

Each rebuild resolves current package versions from the YAML files. Nothing is
pinned and no environment lockfile is tracked, so environments built at
different times can differ.

## Launch

On the remote host:

```bash
jupyter-remote-lab --detach --dir ~/local-projects/project
```

From your local machine, tunnel the port the launcher printed:

```bash
ssh -N -L 8888:127.0.0.1:8888 <ssh-host>
```

The launcher records its last runtime settings in
`${JUPYTER_REMOTE_ENV_FILE:-~/.local/state/jupyter-remote/current.env}`. After
launching with overrides such as `--port`, run `jupyter_remote_load_env` to load
them into the current shell.

## Tokens

For a custom token, put it in a mode-0600 file and pass the path with
`--token-file`. The launcher copies the file into its mode-0700 state directory
and gives Jupyter only the path. After stopping the server, remove the token
file named by `JUPYTER_REMOTE_TOKEN_FILE` and any old logs that contain
tokenized startup URLs.
