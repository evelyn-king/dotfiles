# Agent 5 deployment review: shell and session behavior (generic and Linux)

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-02

Local review host: Omarchy 4.0.2-1, Linux x86_64, zsh 5.9.2, bash 5.3.15-1,
chezmoi 2.72.0

## Scope

I own the shell startup workstream:

- `.chezmoitemplates/shell-env.sh`
- `.chezmoitemplates/shell-path.sh`
- `.chezmoitemplates/shell-interactive.sh`
- `.chezmoitemplates/shell-omarchy-zsh.zsh`
- `dot_zshenv.tmpl`, `dot_zshrc.tmpl`, `dot_zprofile`
- `dot_bashrc.tmpl`, `dot_bash_profile`
- `dot_profile.tmpl`
- `dot_direnvrc`
- `local-projects/dot_mise.toml`

`dot_inputrc` is not on the assignment list, but `dot_zshrc.tmpl` and
`docs/shell-startup.md` both make claims about it, so I checked those claims.

Everything below was tested on Linux or is platform-independent. I did not run
anything on macOS, did not evaluate `path_helper` ordering, did not exercise
the Homebrew or `/run/current-system/sw/bin` entries in `shell-path.sh`, and
did not test the Darwin `TMPDIR`, `DOCKER_DEFAULT_PLATFORM`, `nix-switch` or
Obsidian branches. A macOS reviewer has to cover those.

## Workstream verdict

Nothing in this workstream blocks a fresh Omarchy apply. Every rendered file
parses under its own shell, missing tools degrade silently with no output at
all, paths containing spaces survive every context I tried, and login and
non-login bash reach identical state. The ordering rules are carefully thought
through and the comments explaining them are accurate about the hard parts,
including the zsh word-splitting trap in the PATH loop.

Two things are wrong enough to fix before deployment.

The first is that the whole "PATH for non-interactive shells" mechanism, which
gets its own section in `docs/shell-startup.md` and a fifteen-line comment in
`shell-env.sh`, does not run on a stock Omarchy host. It depends on bash
sourcing `~/.bashrc` for `ssh host command`. Arch does not build bash that way,
and I confirmed it: bash 5.3.15-1 reads nothing, even with `SSH_CLIENT` set. The
mechanism works when the login shell is zsh, which is the macOS default and
which nothing in this repo arranges on Linux. Omarchy patches over the symptom
with a PAM `PATH` line covering two directories, so remote commands still
resolve, but every environment variable this repo exports is absent.

The second is that zsh, the daily shell, keeps no command history. `HISTFILE`
is unset, `SAVEHIST` is 0, and `HISTSIZE` is zsh's default 30. Bash gets
100000 lines and a real history file. Atuin covers `Ctrl-R`, so this hides
well, but arrow-key recall dies after 30 commands and nothing survives a
restart if atuin is missing, broken, or not yet installed. A fresh host has no
recall at all until the package hook finishes.

The rest are smaller: a locale that disagrees with the host, a documented
override that does not reach the context it is documented for, and a handful of
things stock Omarchy sets that the replacement drops.

## Startup file matrix

What each context actually reads, verified on the review host.

| Context | Files read | PATH built | `extras.sh` | Omarchy `env-bootstrap` |
| --- | --- | --- | --- | --- |
| interactive zsh (login or not) | `.zshenv`, `.zshrc` | `.zshrc` | yes | yes |
| non-interactive zsh (`zsh -c`) | `.zshenv` | `.zshenv` | no | yes |
| interactive bash, handoff on | `.bashrc`, then execs zsh | `.zshrc` | yes | yes, twice |
| interactive bash, `SHELL_PREFER_ZSH=0` | `.bash_profile`, `.bashrc` | `.bashrc` | yes | yes |
| login bash | `.bash_profile` sources `.bashrc` | same as above | yes | yes |
| `sh -l`, non-interactive login POSIX shell | `.profile` | `.profile` | no | yes |
| `ssh host cmd`, zsh login shell | `.zshenv` | `.zshenv` | no | yes |
| `ssh host cmd`, bash login shell | none | no | no | no |
| cron, `sh -c` | none | no | no | no |
| git hook | none | no | no | no |
| systemd user unit | none | no | no | no |

The last four rows are the gap. `docs/shell-startup.md:32-38` names SSH
commands, cron, launchd and git hooks as the cases the non-interactive build
fixes. On Linux it fixes one of them, and only when the login shell is zsh.

## PATH order

Verified with `env -i HOME=… PATH=/usr/bin:/bin zsh -c` on the review host.
Directories that do not exist are skipped, so the list is what a populated host
gets.

1. `$GOPATH/bin` (never existence-checked, by design)
2. `$XDG_DATA_HOME/mise/shims`
3. `~/.local/bin`
4. `~/.cargo/bin`
5. `$BUN_INSTALL/bin`
6. `~/.rd/bin`
7. `~/.config/emacs/bin`
8. `~/.nix-profile/bin`, `/run/current-system/sw/bin`, `/nix/var/nix/profiles/default/bin`
9. `/opt/homebrew/bin`, `/opt/homebrew/sbin` (macOS only in practice)
10. everything inherited, minus anything already listed
11. `~/.pixi/bin`

First occurrence wins, so running the body twice does not reorder anything. I
confirmed that by sourcing `.zshrc` again inside a live shell. `MANPATH` is the
exception and does grow, see A5-008.

The hand-rolled `while` loop over `$PATH` rather than an `IFS` split is correct
and the comment explaining why is right: zsh does not word-split unquoted
parameters, so the obvious bash idiom would silently iterate once.

Linux Homebrew (`/home/linuxbrew/.linuxbrew/bin`) is absent from the list.
That looks deliberate given the package split, and I found nothing on Linux
that wants it.

## Environment the replacement drops

`~/.bashrc` replaces Omarchy's, which is `default/bash/env-bootstrap` followed
by `default/bash/rc`. `shell-env.sh` re-sources `env-bootstrap`, and
`docs/shell-startup.md:77-84` explains, convincingly, why `rc` is not sourced
and lists what is taken piecemeal instead. What that list misses is
`default/bash/envs`, which `rc` sources first.

| Variable | Stock Omarchy | This repo | Effect |
| --- | --- | --- | --- |
| `EDITOR` | `omarchy-launch-editor --inline` | `nvim` | deliberate |
| `SUDO_EDITOR` | mirrors `EDITOR` | unset | none, `sudoedit` falls back to `VISUAL` |
| `BROWSER` | `omarchy-launch-browser` | unset | terminal tools lose the detached URL opener |
| `BAT_THEME` | `ansi` | unset | none, `dot_config/bat/config` names Gruvbox directly |
| `MANROFFOPT` | `-c` | unset | man pages lose color |
| `MANPAGER` | `sh -c 'col -bx \| bat -l man -p'` | unset | man pages lose bat |
| `LANG` fallback | `/etc/locale.conf`, then `C.UTF-8` | probe preferring `C.UTF-8` | see A5-003 |

`BAT_THEME` is a non-issue, and I nearly filed it before checking
`dot_config/bat/config`. The repo owns bat's theme directly, which is exactly
what the theming section of the README says it does. The man page pair is a
real if small regression, and `BROWSER` is worth a decision rather than an
accident.

Omarchy's `default/bash/fns` supplies 20 shell functions and four private
helpers. Bash gets all of them; zsh gets the one native port of `tdl`. That is
a documented choice and I agree with the reasoning, but the list of what zsh
does without is not written down anywhere: `compress`, `dip`, `dsw`, `fip`,
`format-drive`, `ga`, `gd`, `hdl`, `hdlm`, `hds`, `hsl`, `iso2sd`, `lip`,
`lsw`, `rsw`, `ssh`, `tdlm`, `tds`, `tsl`. Note `ssh` in that list: bash gets
Omarchy's reconnect wrapper over the real `ssh`, and zsh does not. Two shells
on the same host disagree about what `ssh` does.

## Findings

### A5-001

Finding ID: A5-001

Severity: high

Platform and scenario: Fresh Omarchy 4 account, default bash login shell,
`ssh host command`

Deployment phase: Post-apply, remote use

Files and lines: `.chezmoitemplates/shell-env.sh:92-114`,
`docs/shell-startup.md:26-41`, `dot_bashrc.tmpl:8-13`

Observed behavior: `shell-env.sh` builds PATH behind a non-interactive guard so
that shells which never reach an rc file still get one. For zsh this works,
because zsh reads `~/.zshenv` on every invocation. For bash it depends on bash
sourcing `~/.bashrc` when sshd starts it, which requires `SSH_SOURCE_BASHRC` at
compile time. Arch does not enable it. On the review host, bash 5.3.15-1 read
nothing for a non-interactive shell with `SSH_CLIENT` and `SSH_CONNECTION` set
and with a socket on stdin. Nothing in the repo runs `chsh`, and the review
host's own login shell is still `/usr/bin/bash`.

Fresh-host consequence: `ssh host command` on Omarchy gets no `EDITOR`, no
`XDG_*`, no `GOPATH`, no `MAMBA_ROOT_PREFIX`, no `JUPYTER_*`, no
`OMARCHY_PATH`, no locale normalization, and none of `~/.cargo/bin`,
`$BUN_INSTALL/bin`, `~/.config/emacs/bin` or `~/.pixi/bin` on PATH. Commands
still resolve, because Omarchy appends the mise shims and `~/.local/bin` to
`PATH` in `/etc/security/pam_env.conf`, but that is Omarchy's fix, not this
repo's, and it covers two directories out of eleven.

Reproduction or evidence:

```bash
env -i HOME=$HOME PATH=/usr/bin:/bin SSH_CLIENT="10.0.0.1 1 22" \
  SSH_CONNECTION="10.0.0.1 1 10.0.0.2 22" bash -c 'echo "$PATH"'
# /usr/bin:/bin
env -i HOME=$HOME PATH=/usr/bin:/bin zsh -c 'echo "$PATH"'
# full built PATH
getent passwd "$USER" | cut -d: -f7
# /usr/bin/bash
```

Omarchy's own `install/config/ssh-command-path.sh` states the cause: "SSH
commands (ssh host cmd) run without a login or interactive shell, so on Arch
the PAM environment is the only place they can inherit PATH from."

Automated or manual: Undocumented manual step

Current workaround: `chsh -s "$(command -v zsh)"`, then log out and back in.
After that every row of the startup matrix behaves as documented.

Recommended change: Either add the `chsh` step to the Omarchy cold-start
runbook and say plainly that the non-interactive build only reaches zsh
sessions, or correct `docs/shell-startup.md` and the `shell-env.sh` comment to
scope the claim to zsh and to macOS. Setting the login shell is the better fix:
it also removes the double startup in A5-016. It cannot be done from a chezmoi
hook without a password prompt, so it belongs in documentation either way.

Verification: Set the login shell to zsh, then confirm
`ssh localhost 'echo "$MAMBA_ROOT_PREFIX $LANG"; echo "$PATH"'` returns the
full environment.

Confidence: verified

### A5-002

Finding ID: A5-002

Severity: medium

Platform and scenario: Every platform, zsh, all sessions

Deployment phase: Post-apply, daily use

Files and lines: `dot_zshrc.tmpl` (no history block anywhere),
`dot_bashrc.tmpl:38-46` for the contrast

Observed behavior: `~/.bashrc` sets `HISTSIZE`, `HISTFILESIZE`, `HISTCONTROL`
and `shopt -s histappend`. `~/.zshrc` sets nothing. zsh's defaults are
`HISTFILE` unset, `SAVEHIST=0` and `HISTSIZE=30`, so zsh writes no history file
and remembers 30 commands within the session. `atuin init zsh` does not set any
of them; atuin keeps its own database and binds `Ctrl-R`, which is why this
hides.

Fresh-host consequence: Up-arrow recall stops working after 30 commands. No
`~/.zsh_history` is ever created, so nothing survives closing the terminal
outside atuin. On a fresh host, between the first login and the package hook
installing atuin, there is no history at all. The comment at
`dot_bashrc.tmpl:38-40` says "zsh needs no equivalent block: atuin owns history
in both shells", which is true for `Ctrl-R` and not true for anything else.

Reproduction or evidence:

```bash
zsh -ic 'echo "HISTFILE=${HISTFILE:-UNSET} HISTSIZE=$HISTSIZE SAVEHIST=$SAVEHIST"'
# HISTFILE=UNSET HISTSIZE=30 SAVEHIST=0
ls ~/.zsh_history
# No such file or directory
bash -ic 'echo "$HISTFILE $HISTSIZE"'
# /home/evelyn/.bash_history 100000
```

Automated or manual: Automated defect

Current workaround: Set the three variables by hand in
`~/.config/shell/extras.sh`.

Recommended change: Add a history block to `dot_zshrc.tmpl` mirroring the bash
one: `HISTFILE="$XDG_STATE_HOME/zsh/history"`, `HISTSIZE=100000`,
`SAVEHIST=100000`, plus `setopt APPEND_HISTORY HIST_IGNORE_ALL_DUPS`. It cannot
go in `shell-interactive.sh`, which is shared and POSIX.

Verification: `zsh -ic 'echo $SAVEHIST'` returns 100000, and a second shell
sees commands from the first.

Confidence: verified

### A5-003

Finding ID: A5-003

Severity: medium

Platform and scenario: Omarchy, non-interactive shells and any session that
starts from a bare environment

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh:21-35`

Observed behavior: The locale probe keeps a valid inherited `LANG`, and
otherwise walks `C.UTF-8`, `en_US.UTF-8`, `C` and takes the first that works.
It never reads `/etc/locale.conf`. Omarchy's `default/bash/envs` does read it,
for the stated reason that `/etc/profile.d/locale.sh` only runs for login
shells. So where the two disagree, the repo picks `C.UTF-8` and the host is
configured for `en_US.UTF-8`.

Fresh-host consequence: A shell started from a clean environment gets
`C.UTF-8`, while the desktop session and every login shell get `en_US.UTF-8`.
Date formatting, `sort` collation, number formatting and `LC_MESSAGES` all
differ between a script run locally and the same script run over SSH. Both are
UTF-8, so nothing renders as escapes, which makes this quiet rather than loud.

Reproduction or evidence:

```bash
cat /etc/locale.conf                                   # LANG=en_US.UTF-8
env -i HOME=$HOME PATH=/usr/bin:/bin zsh -c 'echo $LANG'  # C.UTF-8
env -i HOME=$HOME PATH=/usr/bin:/bin bash -c \
  '. /usr/share/omarchy/default/bash/envs; echo $LANG'    # en_US.UTF-8
```

Automated or manual: Automated defect

Current workaround: None in the repo.

Recommended change: Source `/etc/locale.conf` before the fallback walk when it
is readable, matching Omarchy. Keep the probe as the last resort for hosts that
have no such file, which is what makes it portable to macOS.

Verification: The `env -i` command above returns `en_US.UTF-8`.

Confidence: verified

### A5-004

Finding ID: A5-004

Severity: medium

Platform and scenario: Every platform, remote and scheduled use

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-interactive.sh:242-248`,
`.chezmoitemplates/shell-env.sh:57-60`, `README.md:97,154-155`,
`docs/shell-startup.md:97-103`

Observed behavior: `~/.config/shell/extras.sh` is sourced near the end of
`shell-interactive.sh`, which only runs in interactive shells.
`JUPYTER_BIND_HOST`, `JUPYTER_ENV_NAME` and `JUPYTER_PORT` are exported in
`shell-env.sh`, which also runs in non-interactive ones. Both the README and
`docs/shell-startup.md` name `JUPYTER_PORT` as the example of what belongs in
`extras.sh`, and the README's own usage example is
`jupyter-remote-lab --detach --dir …` on a remote host.

Fresh-host consequence: A per-machine `JUPYTER_PORT` set in `extras.sh` applies
when you type the command in a terminal and not when you run it over SSH. The
same is true for `MAMBA_ROOT_PREFIX`, the other variable the documentation
names. On Omarchy this compounds with A5-001, where `extras.sh` and
`shell-env.sh` both go unread over SSH.

Reproduction or evidence:

```bash
printf 'export JUPYTER_PORT=9999\n' > "$HOME/.config/shell/extras.sh"
zsh -ic 'echo $JUPYTER_PORT'   # 9999
zsh -c  'echo $JUPYTER_PORT'   # 8888
```

Automated or manual: Documented behavior that does not match the code

Current workaround: Duplicate the override into a context the non-interactive
path reads, or pass the variable on the command line.

Recommended change: Source `extras.sh` at the end of `shell-env.sh` instead, so
it lands after the defaults and reaches every context that got the defaults.
The interactive-only pieces a machine might want to override, such as aliases,
still work from there because `shell-env.sh` runs first in both rc files. If
the current placement is deliberate, add a second hook for the environment half
and correct both documents.

Verification: The `zsh -c` line above returns 9999.

Confidence: verified

### A5-005

Finding ID: A5-005

Severity: medium

Platform and scenario: Every platform, any caller that passes environment in

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh:57-60`

Observed behavior: Three of the four Jupyter variables are assigned
unconditionally and overwrite whatever the parent set.
`JUPYTER_REMOTE_ENV_FILE` on the next line uses `${VAR:-default}`, and
`MAMBA_ROOT_PREFIX` at line 55 does too, so the file is inconsistent with
itself.

Fresh-host consequence: `ssh -o SendEnv=JUPYTER_PORT`, a systemd user unit with
`Environment=JUPYTER_PORT=…`, and a parent process that exports a value all
lose it. Command-prefix assignment (`JUPYTER_PORT=9000 jupyter-remote-lab`)
still works, because it applies after the rc has run. The consuming scripts all
use `${JUPYTER_PORT:-8888}` style defaults, so honoring the inherited value
costs nothing.

Reproduction or evidence:

```bash
env -i HOME=$HOME PATH=/usr/bin:/bin JUPYTER_PORT=7777 JUPYTER_ENV_NAME=mine \
  JUPYTER_BIND_HOST=0.0.0.0 MAMBA_ROOT_PREFIX=/opt/mm \
  zsh -c 'echo "$JUPYTER_PORT $JUPYTER_ENV_NAME $JUPYTER_BIND_HOST $MAMBA_ROOT_PREFIX"'
# 8888 jupyter 127.0.0.1 /opt/mm
```

Automated or manual: Automated defect

Current workaround: Set the value on the command line rather than in the
environment.

Recommended change: Use `${VAR:-default}` for all three, matching the two lines
around them.

Verification: The command above returns `7777 mine 0.0.0.0 /opt/mm`.

Confidence: verified

### A5-006

Finding ID: A5-006

Severity: low

Platform and scenario: Omarchy, terminal tools that open URLs and man pages

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh` (nothing sets these),
`/usr/share/omarchy/default/bash/envs:1-12`

Observed behavior: Replacing `~/.bashrc` drops Omarchy's `envs`, and with it
`BROWSER=omarchy-launch-browser`, `MANPAGER="sh -c 'col -bx | bat -l man -p'"`
and `MANROFFOPT=-c`. `docs/shell-startup.md:77-84` enumerates what the repo
takes back from Omarchy's rc chain and does not mention `envs` at all, which
reads like an oversight rather than a decision.

Fresh-host consequence: Man pages render without color or bat. Terminal tools
that shell out to `$BROWSER` fall back to `xdg-open`. Omarchy's comment on
`BROWSER` says it is shell-scoped on purpose so that `xdg-settings` can still
change the default browser, and that it exists to open URLs detached from the
terminal process tree, so losing it can leave a CLI blocked on a browser.

Reproduction or evidence:

```bash
zsh -ic 'echo "${BROWSER:-unset} | ${MANPAGER:-unset} | ${MANROFFOPT:-unset}"'
# unset | unset | unset
```

Automated or manual: Automated regression from stock Omarchy

Current workaround: Set them in `~/.config/shell/extras.sh`.

Recommended change: Decide each one and record the decision. The man pair costs
two lines and the repo already themes bat. `BROWSER` is a genuine question,
since `omarchy-launch-browser` is an Omarchy command and the same file has to
render on macOS, so it needs the Linux guard the aliases already use.

Verification: `MANPAGER` and `MANROFFOPT` set, and `man ls` renders through
bat.

Confidence: verified

### A5-007

Finding ID: A5-007

Severity: low

Platform and scenario: Every platform, cron jobs and git hooks

Deployment phase: Post-apply

Files and lines: `docs/shell-startup.md:32-38`,
`.chezmoitemplates/shell-env.sh:98-103`

Observed behavior: Both the document and the comment say the non-interactive
build fixes "SSH commands, cron and launchd jobs, and git hooks". Cron runs
`/bin/sh -c`, which reads no rc file. Git executes hooks directly, so a hook
with a `#!/bin/bash` shebang is a non-interactive non-login bash, which also
reads nothing. Neither is fixed, on any platform, regardless of login shell.

Fresh-host consequence: Nothing breaks that was not already broken. The cost is
that the document tells a future reader the problem is solved, so the next
"command not found" in a git hook gets debugged in the wrong place.

Reproduction or evidence:

```bash
# a pre-commit hook printing $PATH, run under env -i
HOOK PATH: /usr/lib/git-core:/usr/bin:/bin
env -i HOME=$HOME PATH=/usr/bin:/bin /bin/sh -c 'echo "$PATH"'
# /usr/bin:/bin
```

Automated or manual: Documentation defect

Current workaround: None needed.

Recommended change: Narrow the claim to shells that read a startup file, and
name what covers the rest: cron entries need their own `PATH=` line, git hooks
need an absolute path or a shebang of `#!/usr/bin/env zsh`, and systemd user
units need `Environment=` or an imported environment.

Verification: Reading.

Confidence: verified

### A5-008

Finding ID: A5-008

Severity: low

Platform and scenario: Every platform, re-sourcing an rc file

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-path.sh:91-92`,
`docs/shell-startup.md:40-41`

Observed behavior: The PATH build is idempotent and the document says so. The
`MANPATH` line at the end of the same body is not: it prepends
`$HOME/.local/share/man` unconditionally, so every extra run adds another copy.

Fresh-host consequence: `source ~/.zshrc`, the ordinary way to reload after an
apply, grows `MANPATH` by one entry each time. `man` tolerates duplicates, so
this is cosmetic, but it contradicts a stated invariant of the file.

Reproduction or evidence:

```bash
zsh -ic 'source ~/.zshrc; echo "$MANPATH"'
# /home/evelyn/.local/share/man:/home/evelyn/.local/share/man:
```

Automated or manual: Automated defect

Current workaround: Open a new shell instead of re-sourcing.

Recommended change: Guard it the same way PATH is guarded, with a `case`
against `":$MANPATH:"`.

Verification: The command above shows one copy.

Confidence: verified

### A5-009

Finding ID: A5-009

Severity: low

Platform and scenario: Every platform, zsh, leaving vi insert mode

Deployment phase: Post-apply

Files and lines: `dot_inputrc:4-7`, `dot_zshrc.tmpl` (no `KEYTIMEOUT`)

Observed behavior: Commit 87bb4fa cut readline's `keyseq-timeout` to 25ms so
that Esc leaves insert mode without a visible pause. zsh has the same problem
and its own knob, `KEYTIMEOUT`, which nothing sets. It is still at the default
40, meaning 400ms.

Fresh-host consequence: The fix landed in bash, which the handoff exists to get
you out of, and not in zsh, which is where the delay is actually felt every
day.

Reproduction or evidence:

```bash
zsh -ic 'echo $KEYTIMEOUT'   # 40
grep -rn KEYTIMEOUT .        # no match
```

Automated or manual: Automated gap

Current workaround: `KEYTIMEOUT=2` in `~/.config/shell/extras.sh`.

Recommended change: `KEYTIMEOUT=2` in `dot_zshrc.tmpl`, next to the other
zsh-only settings, with a comment pointing at the `dot_inputrc` line it mirrors.

Verification: `zsh -ic 'echo $KEYTIMEOUT'` returns 2.

Confidence: verified

### A5-010

Finding ID: A5-010

Severity: low

Platform and scenario: Every platform, zsh keybindings

Deployment phase: Post-apply

Files and lines: `dot_zshrc.tmpl` (no `bindkey -v`),
`.chezmoitemplates/shell-env.sh:9-10`

Observed behavior: zsh is in vi mode on this host, but nothing sets it. zsh
picks `viins` as the default keymap when `$VISUAL` or `$EDITOR` contains the
substring "vi", and `shell-env.sh` sets `EDITOR=nvim`. `bindkey -lL main`
confirms `bindkey -A viins main`.

Fresh-host consequence: Changing `EDITOR` to `hx`, `code`, `emacs` or anything
else without "vi" in the name silently reverts the daily shell to emacs
keybindings. Nothing in the repo connects those two lines, so the next person
to change the editor will not see it coming.

Reproduction or evidence:

```bash
zsh -ic 'bindkey -lL main'
# bindkey -A viins main
env -i PATH=/usr/bin:/bin EDITOR=nvim zsh -fc 'bindkey -lL main'
# bindkey -A viins main
env -i PATH=/usr/bin:/bin EDITOR=hx zsh -fc 'bindkey -lL main'
# bindkey -A emacs main
```

Automated or manual: Implicit behavior

Current workaround: None needed while the editor is Neovim.

Recommended change: Add an explicit `bindkey -v` to `dot_zshrc.tmpl`. One line,
and it makes the intent visible next to the `dot_inputrc` counterpart.

Verification: `env -i PATH=/usr/bin:/bin EDITOR=hx zsh -ic 'bindkey -lL main'`
reports `viins`.

Confidence: verified

### A5-011

Finding ID: A5-011

Severity: low

Platform and scenario: Every platform, bash completions

Deployment phase: Post-apply

Files and lines: `dot_bashrc.tmpl:60-74`

Observed behavior: `BASH_COMPLETION_USER_DIR` is exported after the loop that
sources `bash_completion`. bash-completion reads it at source time, in
`_comp__init_collect_startup_configs`, to pick up a user's startup config, so
setting it afterwards is too late for that. The value assigned is also
`$XDG_DATA_HOME/bash-completion`, which is exactly bash-completion's own
default, so the line has no effect either way.

Fresh-host consequence: None today, since nothing in the repo writes to that
directory. Dynamic per-command completions under `completions/` still load,
because `_comp_load` re-reads the variable at completion time.

Reproduction or evidence:

```bash
grep -n "BASH_COMPLETION_USER_DIR" /usr/share/bash-completion/bash_completion
# 3542 inside _comp_load, 3676 inside _comp__init_collect_startup_configs
grep -n "^[^ \t].*BASH_COMPLETION_USER_DIR" /usr/share/bash-completion/bash_completion
# no top-level read
```

Automated or manual: Automated defect with no current effect

Current workaround: None needed.

Recommended change: Delete the line, or move it above the sourcing loop if the
intent is to make the path explicit rather than implicit.

Verification: Completions still work after the change.

Confidence: verified

### A5-012

Finding ID: A5-012

Severity: low

Platform and scenario: Every platform, a project directory whose name contains
a space

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-interactive.sh:172-177`

Observed behavior: `create_direnv_micromamba` writes
`layout micromamba $env_name` into `.envrc` without quoting. The default name
comes from `${PWD##*/}`, so a directory called `my project` produces
`layout micromamba my project`, and direnv passes two arguments to
`layout_micromamba`, which takes one.

Fresh-host consequence: The generated `.envrc` activates an environment named
`my`, or fails, depending on what exists. The rest of the shell handles spaces
correctly, which I checked with a `$HOME` containing one, so this is the single
place that does not.

Reproduction or evidence:

```bash
mkdir "/tmp/my project" && cd "/tmp/my project"
# create_direnv_micromamba writes: layout micromamba my project
```

Automated or manual: Automated defect

Current workaround: Pass the name explicitly, or edit `.envrc` afterwards.

Recommended change: Quote it in the generated file:
`printf 'layout micromamba %s\n' "'$env_name'"`, or reject names containing
whitespace with a message.

Verification: The generated `.envrc` activates the full directory name.

Confidence: verified

### A5-013

Finding ID: A5-013

Severity: low

Platform and scenario: Every platform, `layout micromamba` in a `.envrc`

Deployment phase: Post-apply

Files and lines: `dot_direnvrc:3-17`

Observed behavior: The function picks a shell for `micromamba shell hook` from
`DIRENV_SHELL` first, then `ZSH_VERSION`, then `BASH_VERSION`. direnv always
evaluates `.direnvrc` in its own bash, so on a zsh host `DIRENV_SHELL` is `zsh`
and the code asks micromamba for the zsh hook and then evals it in bash. It
works only because micromamba emits byte-identical text for both shells, which
I confirmed with a diff.

Fresh-host consequence: None today. It is a latent break if micromamba ever
differentiates the two hooks, and the detection ladder invites a reader to
believe direnv runs this file in their login shell.

Reproduction or evidence:

```bash
diff <(micromamba shell hook --shell=bash) <(micromamba shell hook --shell=zsh)
# identical
```

Automated or manual: Latent defect

Current workaround: None needed.

Recommended change: Use `--shell=bash` unconditionally and say why in a
comment, since that is the shell direnv actually evaluates the file in.

Verification: `direnv exec . true` in a directory with
`layout micromamba <existing env>` activates it under both login shells.

Confidence: verified

### A5-014

Finding ID: A5-014

Severity: low

Platform and scenario: Linux desktop session with a keyring or systemd SSH
agent

Deployment phase: Post-apply, first interactive shell after boot

Files and lines: `.chezmoitemplates/shell-interactive.sh:19-35`

Observed behavior: The forwarded-agent branch only recognizes an
`SSH_AUTH_SOCK` matching `/tmp/ssh-*/agent.*`, which is OpenSSH's forwarding
path. Any other agent, including a local session where `SSH_CONNECTION` is
unset, falls through to `keychain`, which starts or reuses its own agent and
replaces `SSH_AUTH_SOCK`. On the review host, `gcr-ssh-agent.socket` and
`ssh-agent.socket` are both installed but disabled, so keychain wins
uncontested and this is currently theoretical.

Fresh-host consequence: If a user enables the gnome-keyring or systemd agent,
or uses 1Password's agent at `~/.1password/agent.sock`, every interactive shell
silently overrides it with keychain's. Keys already unlocked by the desktop are
ignored and keychain prompts for the passphrase instead. That prompt is also
the first thing a new terminal does after a reboot, blocking startup until it
is answered or cancelled.

Reproduction or evidence:

```bash
echo "$SSH_AUTH_SOCK"   # /home/evelyn/.keychain/39p9U5dg.s
systemctl --user list-unit-files | grep ssh
# gcr-ssh-agent.socket disabled, ssh-agent.socket disabled
```

Automated or manual: Undocumented manual step (the passphrase prompt)

Current workaround: `SSH_AUTH_SOCK` is honored if it matches the OpenSSH
forwarding pattern; nothing else is.

Recommended change: Accept any reachable agent rather than only the forwarded
pattern. Probing `ssh-add -l` against whatever `SSH_AUTH_SOCK` already names,
and running keychain only when that fails, covers both cases with less code.
Separately, list the keychain passphrase prompt in the manual-state inventory.

Verification: With `ssh-agent.socket` enabled, a new shell keeps the systemd
socket.

Confidence: verified for the mechanism, hypothesis for the keyring conflict on
a host that enables one

### A5-015

Finding ID: A5-015

Severity: low

Platform and scenario: Omarchy, bash and zsh side by side

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-interactive.sh:195-240`,
`.chezmoitemplates/shell-omarchy-zsh.zsh`, `docs/shell-startup.md:86-91`

Observed behavior: Bash sources all of Omarchy's `default/bash/fns`, which
defines 20 functions plus four private helpers. zsh gets one native port,
`tdl`. The document explains the policy and I think the policy is right. What
it does not do is name what zsh gives up, and one of those names is `ssh`:
Omarchy's `fns/ssh-reconnect` wraps the real command, so bash and zsh on the
same host behave differently when you type `ssh`.

Fresh-host consequence: Muscle memory built in one shell does not transfer. A
user who drops to bash for a recovery shell gets a different `ssh`, and neither
behavior is documented.

Reproduction or evidence:

```bash
grep -hoE '^[a-zA-Z_][a-zA-Z0-9_-]*\s*\(\)' /usr/share/omarchy/default/bash/fns/* \
  | tr -d ' ()' | sort -u
# compress dip dsw fip format-drive ga gd hdl hdlm hds hsl iso2sd lip lsw rsw
# ssh tdl tdlm tds tsl (plus four _-prefixed helpers)
```

Automated or manual: Documented policy with an undocumented consequence

Current workaround: Use bash for those helpers.

Recommended change: List the names in `docs/shell-startup.md`, and call out
`ssh` specifically. Porting more of them is a separate decision; the list is
what makes that decision possible.

Verification: Reading.

Confidence: verified

### A5-016

Finding ID: A5-016

Severity: low

Platform and scenario: Omarchy with the default bash login shell, every new
terminal

Deployment phase: Post-apply

Files and lines: `dot_bashrc.tmpl:15-33`

Observed behavior: Because nothing sets the login shell (A5-001), every
terminal starts bash, runs `shell-env.sh` in full including the locale probe
and Omarchy's `env-bootstrap`, then `exec`s zsh, which runs both again. The
handoff itself is well built: `__SHELL_ZSH_HANDOFF` prevents a loop, an
interactive bash survives a failed `exec`, `SHELL_PREFER_ZSH=0` opts out, and I
confirmed the fallback when zsh is absent.

Fresh-host consequence: A few milliseconds per terminal and one extra process
per session, plus the `exec` discards a `bash -c` command supplied at startup.
Nothing user-visible. It disappears entirely once the login shell is zsh, which
is the fix for A5-001 anyway.

Reproduction or evidence:

```bash
script -qec "bash -i <<< 'echo \$0 \${__SHELL_ZSH_HANDOFF}; exit'" /dev/null
# /usr/bin/zsh 1
```

Automated or manual: Automated, working as designed

Current workaround: None needed.

Recommended change: None on its own. Note it as one more reason to prefer
`chsh` over the handoff as the primary mechanism, and keep the handoff as the
fallback it was built to be.

Verification: With zsh as the login shell, `__SHELL_ZSH_HANDOFF` is unset in a
fresh terminal.

Confidence: verified

### A5-017

Finding ID: A5-017

Severity: low

Platform and scenario: Fresh Omarchy account

Deployment phase: First apply

Files and lines: `local-projects/dot_mise.toml`,
`run_onchange_after_trust-local-projects-mise.sh.tmpl`,
`/usr/share/omarchy/install/user/mise-work.sh`

Observed behavior: The repo's `~/local-projects/.mise.toml` is byte-identical
to the one Omarchy's installer writes at `~/Work/.mise.toml`, and the `try`
wrapper is repointed from `~/Work/tries` to `~/local-projects/tries`. Omarchy's
installer still creates `~/Work`, `~/Work/tries` and `~/Work/.mise.toml` on a
fresh account, and trusts that file. `{{ cwd }}` resolves to the current
directory rather than the config's directory, which I verified, so the port is
faithful.

Fresh-host consequence: Two project roots, two trusted mise configs with the
same body, and one of them holds a `tries` directory nothing points at. Harmless
but confusing on a new machine.

Reproduction or evidence:

```bash
cd ~/local-projects/codes/anything && mise env -s bash | grep -o 'codes/anything/bin'
# codes/anything/bin
diff <(chezmoi cat ~/local-projects/.mise.toml) <(sed -n '6,9p' \
  /usr/share/omarchy/install/user/mise-work.sh)
```

Automated or manual: Undocumented leftover state

Current workaround: Delete `~/Work` by hand.

Recommended change: Either say in the README that `~/Work` is Omarchy's and
unused here, or add it to `.chezmoiremove`. The second option needs Agent 7's
view on persistent removals of user directories, so I would not add it without
that.

Verification: A fresh account has one project root, or documentation saying why
it has two.

Confidence: verified

## Manual state in this workstream

| Item | Status |
| --- | --- |
| `chsh -s "$(command -v zsh)"` | undocumented manual work, see A5-001 |
| `mkdir -p ~/.config/shell` and write `extras.sh` | documented, README and `docs/shell-startup.md` |
| keychain passphrase prompt at the first shell after boot | undocumented manual work, see A5-014 |
| SSH key creation or restoration into `~/.ssh/id_ed25519` | outside this workstream, Agent 7 |
| `micromamba create -n <name>` before `layout micromamba` works | `layout_micromamba` only activates; creation is manual |
| Log out and back in after `chsh` | consequence of the first row |

## What converges and what is intentionally unmanaged

Every file in this workstream renders, parses, and converges. A dry-run apply
into an isolated destination produced clean creations for `.bashrc`,
`.bash_profile`, `.profile`, `.zshenv`, `.zshrc`, `.zprofile`, `.direnvrc`,
`.inputrc` and the `local-projects` tree, with no prompts, no removals and no
errors.

`chezmoi status` on the review host reports `.zshrc` and `.inputrc` as
modified. That is not drift: both are the last two commits on this branch
(4a3ff1d and 87bb4fa) and the host has not applied since. Nothing in this
workstream rewrites a managed file at runtime, so `chezmoi status` should be
empty once the host applies.

Deliberately unmanaged, and correctly so:

- `~/.config/shell/extras.sh`. Note that `.chezmoiremove` deletes fourteen of
  its siblings under `.config/shell/` on every apply. `extras.sh` is not on
  that list, so it is safe, but the two live in the same directory and the
  removals are permanent rather than one-time. That is Agent 7's call.
- `~/.zcompdump`. Written by `compinit -C` on first run, which I confirmed
  creates it on a fresh `$HOME`. `compaudit` is clean on the review host, so
  the insecure-directories prompt that a full `compinit` can raise did not
  trigger.
- `~/.bash_history`. Written by bash. There is no zsh equivalent, which is
  A5-002.

## Checks run

Static:

```bash
chezmoi execute-template --file dot_bashrc.tmpl  | bash -n
chezmoi execute-template --file dot_zshrc.tmpl   | zsh -n
chezmoi execute-template --file dot_zshenv.tmpl  | zsh -n
chezmoi execute-template --file dot_zshenv.tmpl  | sh -n     # POSIX claim
chezmoi execute-template --file dot_profile.tmpl | sh -n
chezmoi managed | grep -E 'zsh|bash|profile|direnv|inputrc|local-projects'
chezmoi status
chezmoi --destination "$rd/home" --persistent-state "$rd/state.db" \
  apply --dry-run --force --verbose --refresh-externals=never
```

Behavioral, against rendered copies in a sandbox `$HOME`:

- non-interactive zsh with a minimal inherited `PATH`
- interactive zsh, fresh `$HOME` and populated `$HOME`
- non-interactive bash via `BASH_ENV`, and without it
- interactive bash with the handoff on, off, and with no zsh on `PATH`
- login and non-login bash, compared for identical `PATH`, `HISTSIZE`,
  `hashall` and completion state
- interactive and non-interactive login `sh` reading `~/.profile`
- `$HOME` containing a space, across zsh interactive, zsh non-interactive and
  bash non-interactive
- a `PATH` holding only zsh, bash and coreutils, to check that every optional
  tool degrades silently. It does: no output, no errors, `zsh -x` shows every
  `command -v` guard taking the absent branch.
- inherited `JUPYTER_*` and `MAMBA_ROOT_PREFIX`, checked for clobbering
- `extras.sh` reachability in interactive and non-interactive shells
- `MANPATH` after one build and after re-sourcing `~/.zshrc`
- `LANG` from a clean environment, against `/etc/locale.conf` and against
  Omarchy's `envs`
- forwarded-agent socket pattern matching, and the live `SSH_AUTH_SOCK`
- `micromamba shell hook` output for bash and zsh, diffed
- `direnv allow` and `direnv exec` on a `layout micromamba` `.envrc`
- `mise env` under `~/local-projects/codes/<project>` to resolve `{{ cwd }}`
- a `pre-commit` hook and `sh -c`, both under `env -i`, for the cron and hook
  claims
- `bash -c` with `SSH_CLIENT` set and with a closed stdin, for A5-001

Comparison against packaged Omarchy 4.0.2 defaults, read only:
`default/bash/{env-bootstrap,envs,init,rc,shell,aliases,functions,completions,inputrc}`,
`default/bash/fns/*`, `install/user/mise-work.sh`,
`install/config/ssh-command-path.sh`, `/etc/security/pam_env.conf`,
`/etc/profile.d/omarchy.sh`.

## Checks deferred

To a macOS reviewer:

- `path_helper` ordering and the reason PATH is built in the rc file at all
- the Darwin `TMPDIR` branch and `getconf DARWIN_USER_TEMP_DIR`
- `DOCKER_DEFAULT_PLATFORM=linux/amd64`
- `/opt/homebrew/{bin,sbin}` position relative to the nix profiles
- the `nix-switch` and `mup` aliases in the Darwin branch, including a source
  path containing spaces
- `/Applications/Obsidian.app/Contents/MacOS` on `PATH`
- launchd environments, which have no Linux equivalent
- whether A5-001 exists there at all. It should not: zsh is the macOS default
  login shell and reads `~/.zshenv` unconditionally.

To a disposable cold-start host:

- first, second and third apply transcripts for these files
- the keychain passphrase prompt on a host with a real encrypted key
- `compinit`'s insecure-directories prompt once `~/.zcompdump` passes 24 hours
  on a host whose `fpath` is not clean
- shell startup before the Omarchy package hook has installed atuin, starship,
  zoxide, fzf, eza, bat, fd and keychain
- behavior after `chsh -s /usr/bin/zsh` and a re-login, to confirm A5-001
