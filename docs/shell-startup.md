# Shell Startup Layout

Both zsh and bash are first-class here. zsh is the default; bash is supported
because at least one machine has to run it as the primary interactive shell.

## Where the content lives

The bodies are in `.chezmoitemplates/` and are stitched into the real dotfiles
at apply time, not sourced at runtime:

| Template | Contents |
| --- | --- |
| `shell-env.sh` | environment variables. POSIX, no PATH. |
| `shell-path.sh` | PATH and MANPATH construction. POSIX. |
| `shell-interactive.sh` | ssh agent, tool hooks, aliases, functions, prompt. POSIX, parameterised on `$__shell`. |

and the entry points that include them:

| File | Includes |
| --- | --- |
| `~/.zshenv` | `shell-env.sh` |
| `~/.zshrc` | `shell-path.sh`, `shell-interactive.sh`, plus zsh completions |
| `~/.bash_profile` | nothing — it just sources `~/.bashrc` |
| `~/.bashrc` | `shell-env.sh`, then past an interactive guard the same two as `.zshrc`, plus bash completions and history options |

Sharing at apply time rather than at runtime is deliberate. The rendered
`~/.zshrc` and `~/.bashrc` are each flat, self-contained files you can read
top to bottom — there is no loader, no helper library, and no source chain to
trace when something misbehaves. The cost is that editing a shared body means
running `chezmoi apply` to see it take effect.

Only what genuinely differs between the two shells stays in the entry point.
That is a shorter list than it looks: completion systems, bash's history
options, and zsh's `typeset -U`.

## Why the shared bodies are POSIX

The same text has to parse as both zsh and bash, so: no arrays, no `(N-/)` glob
qualifiers, no `[[ ]]`, no `$+commands`. Tool detection is `command -v x
>/dev/null 2>&1`. Anything that needs the shell's name uses `$__shell`, set at
the top of `shell-interactive.sh` and unset at the bottom.

One trap worth naming, because it looks correct and is not: zsh does not
word-split unquoted parameters. An `IFS=:; for d in $PATH` loop iterates once
in zsh and per-entry in bash. `shell-path.sh` walks PATH with `${var%%:*}`
instead.

## Why PATH lives in the interactive rc

`.zshenv` would be the natural home for PATH, but on macOS `/etc/zprofile` runs
`path_helper` *after* `.zshenv`, and `path_helper` rebuilds PATH with the system
directories in front. Anything prepended earlier ends up shadowed by `/usr/bin`.
Building PATH in `.zshrc` puts it after `path_helper` and keeps the intended
order. `/etc/profile` does the same to bash, so `.bashrc` is the equivalent
point there.

This costs nothing on Linux, where there is no `path_helper` to work around.

The tradeoff: non-interactive shells inherit PATH from their parent rather than
constructing it. That is normal, and scripts in `~/.local/bin` do not depend on
the shell config for it.

## PATH conventions

First occurrence wins, and the explicit list is built first — so **listing a
directory in `shell-path.sh` is what fixes its position**, rather than
inheriting wherever `/etc` happened to put it. This reproduces what `typeset -U
path` gave the zsh-only version.

It matters concretely: a system `/etc/zshrc` may already have the Nix profiles
on PATH in some other order. Deduplicating against the inherited PATH — instead
of rebuilding it — would silently let that inherited order win.

Directories are added only if they exist, so a machine without cargo or pixi
gets no dead PATH members. The exception is `$GOPATH/bin`, added
unconditionally because the first `go install` creates it.

## Ordering constraints

Three things are order-sensitive:

- `compinit` (zsh) must run before anything calling `compdef`, which is why
  completions are set up in the entry point before `shell-interactive.sh` is
  included.
- **Nothing above `mise activate` may depend on a mise-managed tool.** mise
  supplies `node`, `python`, `go` and every global CLI tool, but it does not
  activate until the tool-integration block, well after PATH is built. This is
  why `GOPATH` is exported in `shell-env.sh` rather than guarded behind a
  `command -v go` check — such a check runs before activation and would always
  be false, silently dropping `$GOPATH/bin` from PATH.
- `starship`, `zoxide`, and `atuin` init last, so `/etc/zshrc` has finished its
  prompt reset before `starship` installs its own.

## Completions

zsh picks up completions from any `site-functions` directory a package manager
has put on `fpath`; the `fpath` line in `.zshrc` is only for the rest.

bash looks for `bash-completion` in the usual places and stops at the first
hit. `atuin` needs no help: since v18 it carries its own copy of `bash-preexec`
internally, so `atuin init bash` is self-sufficient.

## Reach

Tool activation runs in the interactive rc, so mise's runtimes and tools exist
at a prompt and nowhere else — not in a non-interactive shell, not in a process
launched from a GUI app. `~/.local/bin` is equally interactive-only, since PATH
is built there too. If it ever bites, `mise activate --shims` is the
alternative.

## Machine-local additions

`~/.config/shell/extras.sh` is sourced at the end if present. It is not managed
by this repo — create it by hand on a machine that needs local-only settings.
Keep secrets there rather than in tracked files. `~/.config/git/config.local`
is the git equivalent.
