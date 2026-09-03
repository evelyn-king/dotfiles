# Shell startup layout

Startup files are flat. The shared bodies live in `.chezmoitemplates/` and
chezmoi inlines them at apply time, so nothing under `.chezmoitemplates/` is
sourced at runtime. The rendered files still read a handful of things at
runtime, each covered below: `~/.bashrc` from `~/.bash_profile`, Omarchy's own
files, and the per-machine hook in `~/.config/shell`.

| Template | Contents |
| --- | --- |
| `shell-env.sh` | environment for every shell, the Omarchy bootstrap, plus PATH for non-interactive ones |
| `shell-path.sh` | the PATH build itself |
| `shell-interactive.sh` | ssh agent, tool hooks, aliases, Omarchy extras, local overrides, prompt |

| Rendered file | Includes |
| --- | --- |
| `~/.zshenv` | `shell-env.sh` |
| `~/.zshrc` | `shell-path.sh`, zsh completions, `shell-interactive.sh` |
| `~/.bashrc` | `shell-env.sh`, `shell-path.sh`, bash history/completions, Omarchy completions, `shell-interactive.sh` |
| `~/.bash_profile` | sources `~/.bashrc` |
| `~/.profile` | `shell-env.sh` |
| `~/.zprofile` | nothing; a comment explaining why |

Edit the templates, never the rendered files.

## Why PATH is built twice

Interactive shells build PATH in the rc file. macOS runs `path_helper` from
`/etc/zprofile` and `/etc/profile`, and it reorders anything an earlier stage
prepended, so the rc file is the first point where an ordering sticks.

`path_helper` only runs for login shells, though. A non-interactive shell never
reaches it, and under zsh never reads `~/.zshrc` at all. Without a second build
such a shell inherits a bare PATH: no `~/.local/bin`, no nix profiles, no mise
shims. That is what makes `ssh host some-command`, cron and launchd jobs, and
git hooks fail with "command not found" while the same command works
interactively. `shell-env.sh` therefore runs the same body behind a
non-interactive guard.

The body is idempotent and first-occurrence-wins, so a shell that somehow
reaches both copies still ends up with the same order.

## Ordering rules

- The mise shims lead, ahead of `~/.local/bin`, so a hand-installed binary
  cannot outrank a pinned version for non-interactive shells.
- Homebrew ranks below the nix profiles. `brew shellenv` is deliberately not
  called from a later stage: it prepends unconditionally and would shadow every
  mise-managed runtime.
- micromamba's shell hook runs *before* `mise activate`, because it prepends
  `$MAMBA_ROOT_PREFIX/condabin` and would otherwise sit ahead of every mise tool
  path. micromamba is itself a mise tool, so it is resolved with `mise which`.
- The rc file brings up completions before it includes
  `shell-interactive.sh`. The tool hooks in there register completions, so
  `compinit` and `bashcompinit` have to have run already.
- The prompt block (starship, zoxide, atuin) stays last.
- bash gets its preexec/precmd hooks from atuin. `atuin init bash` carries its
  own bash-preexec and loads it only when no backend is present, so a copy
  sourced earlier in `~/.bashrc` takes its place and pins that older release.
  On bash 5.3 the current bash-preexec hooks preexec through `PS0` rather than
  the DEBUG trap; the 0.6.0 this repo used to vendor cannot.

## Omarchy

Omarchy's own `~/.bashrc` is two things: `default/bash/env-bootstrap`, and then
`default/bash/rc`. This repo replaces that file, so both would otherwise be
lost.

`shell-env.sh` re-sources `env-bootstrap` in place of `~/.bashrc`. It exports
`OMARCHY_PATH` and appends the mise shims and `~/.local/bin` to PATH.
Omarchy's own comment calls it "needed even for non-interactive shells", and
that is right. Without it an SSH command, systemd user unit, cron job or git
hook gets neither. Putting it in the shared body also hands `OMARCHY_PATH` to
zsh, which Omarchy's bash-only chain never did. `shell-path.sh` reorders
whatever it appends, so the mise shims still lead.

`default/bash/rc` is deliberately *not* sourced. It re-runs `mise activate`,
`starship init` and `zoxide init` on top of the copies in
`shell-interactive.sh`, and its aliases override this repo's. Its `c` passes
`--auto`, its `cx` uses a different permission mode, and it points `cd` at a
zoxide wrapper that fights `zoxide init --cmd cd`. This repo takes the rest of
that chain piecemeal instead: the `omarchy` dispatcher's bash completions,
`set +h`, and the `h`, `a`, `ic`, `ix` and `icx` aliases, each guarded on its
tool being present.

Omarchy's `default/bash/fns` directory is sourced only by Bash. Those files are
not a cross-shell API: several rely on Bash-specific `read` behavior or on
array indexing whose meaning differs in zsh. zsh instead loads
`shell-omarchy-zsh.zsh`, which holds native ports of the few functions used
there. At present that is `tdl`, needed by the `ic`, `ix` and `icx` aliases. An
upstream addition to the Bash directory therefore cannot break zsh startup.

Two pieces need no action: `~/.inputrc` is already Omarchy's
`default/bash/inputrc` plus vi mode, and `default/bash/functions` is only the
`fns/*` loop that `shell-interactive.sh` runs when the active shell is Bash.

## Per-machine overrides

One hook, sourced near the end of `shell-interactive.sh`:

- `~/.config/shell/extras.sh`, untracked. Nothing in this repo creates or
  manages it. This is where a per-machine `JUPYTER_PORT` or
  `MAMBA_ROOT_PREFIX` override belongs.
