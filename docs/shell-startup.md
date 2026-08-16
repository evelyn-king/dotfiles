# Shell Startup Layout

Shell startup is two files:

- `~/.zshenv`: environment variables read by every zsh invocation, interactive
  or not.
- `~/.zshrc`: PATH construction plus all interactive setup — completions, ssh
  agent, tool hooks, aliases, functions, and prompt init.

zsh reads `.zshenv` for every shell and `.zshrc` for interactive shells, so the
split is simply "always" versus "at a prompt".

## Why PATH lives in `.zshrc`

`.zshenv` would be the natural home for PATH, but on macOS `/etc/zprofile` runs
`path_helper` *after* `.zshenv`, and `path_helper` rebuilds PATH with the system
directories in front. Anything prepended in `.zshenv` — Homebrew especially —
would end up shadowed by `/usr/bin`. Building PATH in `.zshrc` puts it after
`path_helper` and keeps the intended order.

The tradeoff: non-interactive shells inherit PATH from their parent rather than
constructing it. That is normal, and scripts in `~/.local/bin` do not depend on
the shell config for it.

## PATH conventions

`typeset -U path` keeps entries unique, first occurrence winning. Directories
use the `(N-/)` glob qualifier so entries that do not exist are dropped rather
than left as dead PATH members:

```zsh
path=(
  "$HOME/.local/bin"(N-/)
  $path
  "$HOME/.pixi/bin"(N-/)
)
```

The exception is `$GOPATH/bin`, added unconditionally because the first
`go install` creates it.

## Ordering constraints

Two things in `.zshrc` are order-sensitive:

- `compinit` must run before anything calling `compdef`, which is why
  completions are set up before the tool integrations.
- `starship`, `zoxide`, and `atuin` init last, so `/etc/zshrc` has finished its
  prompt reset before `starship` installs its own.

## Machine-local additions

`~/.config/shell/extras.sh` is sourced at the end if present. It is not managed
by this repo — create it by hand on a machine that needs local-only settings.
Keep secrets there rather than in tracked files.
