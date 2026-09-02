# Shell Startup Layout

Startup files are flat and self-contained. Nothing is sourced from
`~/.config/shell` at runtime; the shared bodies live in `.chezmoitemplates/`
and chezmoi inlines them at apply time.

| Template | Contents |
| --- | --- |
| `shell-env.sh` | environment for every shell, plus PATH for non-interactive ones |
| `shell-path.sh` | the PATH build itself |
| `shell-interactive.sh` | completions' consumers, tool hooks, aliases, prompt |

| Rendered file | Includes |
| --- | --- |
| `~/.zshenv` | `shell-env.sh` |
| `~/.zshrc` | `shell-path.sh`, zsh completions, `shell-interactive.sh` |
| `~/.bashrc` | `shell-env.sh`, `shell-path.sh`, bash history/completions/preexec, `shell-interactive.sh` |
| `~/.bash_profile` | sources `~/.bashrc` |
| `~/.profile` | `shell-env.sh` |
| `~/.zprofile` | nothing; a comment explaining why |

Edit the templates, never the rendered files.

## Why PATH is built twice

Interactive shells build PATH in the rc file. macOS runs `path_helper` from
`/etc/zprofile` and `/etc/profile`, and it reorders anything an earlier stage
prepended, so the rc file is the first point where an ordering actually sticks.

`path_helper` only runs for login shells, though. A non-interactive shell never
reaches it, and under zsh never reads `~/.zshrc` at all. Without a second build
such a shell inherits a bare PATH: no `~/.local/bin`, no nix profiles, no mise
shims. That is what makes `ssh host some-command`, cron and launchd jobs, and
git hooks fail with "command not found" while the same command works
interactively. `shell-env.sh` therefore runs the same body behind a
non-interactive guard.

The body is idempotent and first-occurrence-wins, so a shell that somehow
reaches both copies still ends up with the same order.

## Ordering rules worth knowing

- The mise shims lead, ahead of `~/.local/bin`, so a hand-installed binary
  cannot outrank a pinned version for non-interactive shells.
- Homebrew ranks below the nix profiles. `brew shellenv` is deliberately not
  called from a later stage: it prepends unconditionally and would shadow every
  mise-managed runtime.
- micromamba's shell hook runs *before* `mise activate`, because it prepends
  `$MAMBA_ROOT_PREFIX/condabin` and would otherwise sit ahead of every mise tool
  path. micromamba is itself a mise tool, so it is resolved with `mise which`.
- The prompt block (starship, zoxide, atuin) stays last.

## Per-machine overrides

Two hooks, both sourced near the end of `shell-interactive.sh`:

- `~/.config/shell/secrets.sh` — tracked but age-encrypted. See
  [encryption.md](encryption.md).
- `~/.config/shell/extras.sh` — untracked. Nothing in this repo creates or
  manages it. This is where a per-machine `JUPYTER_PORT` or
  `MAMBA_ROOT_PREFIX` override belongs.
