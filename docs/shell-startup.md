# Shell startup layout

Startup files are flat. The shared bodies live in `.chezmoitemplates/` and
chezmoi inlines them at apply time, so nothing under `.chezmoitemplates/` is
sourced at runtime. The rendered files do read three things at runtime, each
covered below: `~/.bashrc` from `~/.bash_profile`, Omarchy's own files, and the
per-machine hook in `~/.config/shell`.

| Template | Contents |
| --- | --- |
| `shell-env.sh` | shared environment, the Omarchy bootstrap, non-interactive PATH, local overrides |
| `shell-path.sh` | the PATH build itself |
| `shell-interactive.sh` | ssh agent, tool hooks, aliases, Omarchy extras, prompt |

| Rendered file | Includes |
| --- | --- |
| `~/.zshenv` | `shell-env.sh` |
| `~/.zshrc` | `shell-path.sh`, zsh history/completions, `shell-interactive.sh` |
| `~/.bashrc` | `shell-env.sh`, `shell-path.sh`, bash history/completions, Omarchy completions, `shell-interactive.sh` |
| `~/.bash_profile` | sources `~/.bashrc` |
| `~/.profile` | `shell-env.sh` |
| `~/.zprofile` | nothing; a comment explaining why |

Edit the templates, never the rendered files.

Both interactive shells keep 100,000 history entries. zsh writes to
`$XDG_STATE_HOME/zsh/history` and appends when a shell exits, so open shells do
not interleave commands live. Atuin keeps its own searchable database alongside
the shell-native history.

Shell startup keeps an inherited locale only when the host supports it. Without
one, Linux reads `/etc/locale.conf` and macOS reads the global `AppleLocale`
preference, then both fall back to a portable UTF-8 locale.

## Why PATH is built twice

Interactive shells build PATH in the rc file. macOS runs `path_helper` from
`/etc/profile` for login sh and bash. Stock `/etc/zprofile` also runs it for
login zsh, but nix-darwin replaces that file. Because `path_helper` reorders
anything an earlier stage prepended, the interactive rc file is the first point
where the managed order sticks.

Non-interactive zsh reads `~/.zshenv`, and sshd makes a remote bash command read
`~/.bashrc`. Without a second build those commands inherit a bare PATH with no
`~/.local/bin`, nix profiles or mise shims, which is how `ssh host some-command`
fails with "command not found" while the same command works interactively.
`shell-env.sh` therefore runs the same body behind a non-interactive guard.

Before the first nix-darwin activation, `zsh -lc` is one narrow exception.
Stock `/etc/zprofile` runs `path_helper` after `~/.zshenv` and can reorder the
managed PATH. Cron jobs, launchd jobs, systemd units and directly executed Git
hooks do not read these startup files at all. They need their own PATH setting,
such as `PATH=` in a crontab, `EnvironmentVariables` in a launchd plist,
`Environment=` in a systemd unit, or an absolute command path in a Git hook.

The body is idempotent and first-occurrence-wins, so a shell that somehow
reaches both copies still ends up with the same order.

## Ordering rules

- The mise shims lead, ahead of `~/.local/bin`, so a hand-installed binary
  cannot outrank a pinned version for non-interactive shells.
- Homebrew ranks below the nix profiles. A later stage deliberately never calls
  `brew shellenv`. It prepends unconditionally and would shadow every
  mise-managed runtime.
- micromamba's shell hook runs *before* `mise activate`, because it prepends
  `$MAMBA_ROOT_PREFIX/condabin` and would otherwise sit ahead of every mise tool
  path. micromamba is itself a mise tool, so it is resolved with `mise which`.
- The rc file brings up completions before it includes
  `shell-interactive.sh`. The tool hooks in there register completions, so
  `compinit` and `bashcompinit` have to have run already.
- nix-darwin's global `compinit` is disabled. `~/.zshrc` owns the single
  completion initialization after adding user site-functions to `fpath`.
- The prompt block (starship, zoxide, atuin) stays last.
- bash gets its preexec/precmd hooks from atuin, and nothing else in
  `~/.bashrc` provides them. `atuin init bash` carries its own bash-preexec and
  loads it only when no backend is already present, so any copy sourced earlier
  would take its place and pin that older release. That matters on bash 5.3,
  where current bash-preexec hooks preexec through `PS0` rather than the DEBUG
  trap.

Interactive startup probes an inherited `SSH_AUTH_SOCK` with `ssh-add -l` and
keeps any agent that answers, even one holding no keys. That preserves
forwarded, launchd, systemd, desktop and password-manager agents. Keychain
starts a local agent only when no inherited agent answers.

## Omarchy

Omarchy's own `~/.bashrc` sources two files, `default/bash/env-bootstrap` and
then `default/bash/rc`. This repo replaces `~/.bashrc`, so both would otherwise
be lost.

`shell-env.sh` re-sources `env-bootstrap` in place of `~/.bashrc`. It exports
`OMARCHY_PATH` and appends the mise shims and `~/.local/bin` to PATH.
Omarchy's own comment calls it "needed even for non-interactive shells", and
that is right for remote shell commands. Putting it in the shared body also
hands `OMARCHY_PATH` to zsh, which Omarchy's bash-only chain never did.
`shell-path.sh` reorders whatever it appends, so the mise shims still lead.

`default/bash/rc` is deliberately *not* sourced. It re-runs `mise activate`,
`starship init` and `zoxide init` on top of the copies in
`shell-interactive.sh`, and its aliases override this repo's. Its `c` passes
`--auto`, its `cx` uses a different permission mode, and it points `cd` at a
zoxide wrapper that fights `zoxide init --cmd cd`. This repo takes the rest of
that chain piecemeal instead: the `omarchy` dispatcher's bash completions,
`set +h`, and the `h`, `a`, `ic`, `ix` and `icx` aliases, each guarded on its
tool being present.

Only Bash sources Omarchy's `default/bash/fns` directory. Those files are not a
cross-shell API. Several rely on Bash-specific `read` behavior or on array
indexing whose meaning differs in zsh. zsh instead loads
`shell-omarchy-zsh.zsh`, which ports `tdl` for the `ic`, `ix` and `icx` aliases
and nothing else, so an upstream addition to the Bash directory cannot break zsh
startup. One difference shows up day to day. `ssh` in Bash is Omarchy's
reconnect wrapper, while zsh runs the real `ssh`.

Two pieces need no action. `~/.inputrc` is already Omarchy's
`default/bash/inputrc` plus vi mode, and `default/bash/functions` is only the
`fns/*` loop that `shell-interactive.sh` runs for Bash.

## Per-machine overrides

One hook is sourced at the end of `shell-env.sh`, after the managed defaults and
the non-interactive PATH build:

- `~/.config/shell/extras.sh`, untracked and hand-written. Nothing in this repo
  creates or manages it. Use it for per-machine settings such as
  `JUPYTER_PORT` or `MAMBA_ROOT_PREFIX`.

Interactive and non-interactive shells that read a managed startup file receive
these overrides. Cron, launchd, systemd and directly executed hooks do not read
shell startup and still need their own environment.

Put secrets in the system credential manager or a tool's own protected
authentication file. Do not export long-lived tokens from `extras.sh`. Every
interactive shell and every process it starts would inherit them.

Create `extras.sh` with a private directory and file mode, even when the current
umask is permissive:

```sh
install -d -m 700 "$HOME/.config/shell"
if [ ! -e "$HOME/.config/shell/extras.sh" ]; then
  install -m 600 /dev/null "$HOME/.config/shell/extras.sh"
else
  chmod 600 "$HOME/.config/shell/extras.sh"
fi
```

Keep generated credential files outside the chezmoi source directory. Protect
their parent directory with mode 0700 and the files with mode 0600. Generate a
complete temporary file in the destination directory, then rename it into
place so a shell or application cannot read a partial credential:

```sh
(
  set -eu
  credential_dir="$HOME/.config/example"
  credential_file="$credential_dir/credentials.json"
  install -d -m 700 "$credential_dir"
  credential_tmp=$(mktemp "$credential_dir/.credentials.json.XXXXXX")
  trap 'rm -f "$credential_tmp"' EXIT HUP INT TERM
  chmod 600 "$credential_tmp"
  command-that-writes-credential >"$credential_tmp"
  mv "$credential_tmp" "$credential_file"
  trap - EXIT HUP INT TERM
)
```

Replace the example directory, file and generator with the real ones. Store any
backup in an encrypted secret store, not in this repository or an unencrypted
sync folder.

Before committing, inspect `git status --short`, stage explicit paths, and
inspect `git diff --cached`. Do not rely on `.gitignore` to protect secrets. If
a secret reaches a commit, revoke it before arranging any history rewrite.
