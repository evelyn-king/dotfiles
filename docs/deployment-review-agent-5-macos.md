# Agent 5 deployment review: shell and session behavior (macOS)

Reviewed commit: `abb2e562c5f61d4904a636fe1645863a4feb7722`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-03

Local review host: macOS 26.6.2 (25G83), Apple Silicon arm64, nix-darwin
activated. zsh 5.9.2 and bash 5.3.15 from the nix profile, Apple's zsh 5.9 and
bash 3.2.57 at `/bin`, chezmoi 2.70.5.

`abb2e56` differs from the commit the Linux reviewer used (`30923db`) only in
`docs/`, so the two reports cover the same source state and the finding numbers
can be compared directly. Mine are prefixed `A5M-` to keep them apart from the
Linux `A5-` set.

## Scope

Same workstream as the Linux report: `.chezmoitemplates/shell-*.sh`,
`dot_zshenv.tmpl`, `dot_zshrc.tmpl`, `dot_zprofile`, `dot_bashrc.tmpl`,
`dot_bash_profile`, `dot_profile.tmpl`, `dot_direnvrc`,
`local-projects/dot_mise.toml`, plus the claims `dot_zshrc.tmpl` and
`docs/shell-startup.md` make about `dot_inputrc`.

I took the eight items the Linux reviewer deferred to macOS and worked through
them, then went looking for what else the platform does differently. The answer
to "what else" turned out to be the interesting part: on macOS the repo shares
`~/.zshrc` with a system `/etc/zshrc` that sets history, sets a keymap and runs
its own `compinit`, and none of that has a Linux equivalent. Three of my six
top findings come from that collision.

I did not test Homebrew, which is not installed here, and I could not start the
Docker daemon. Both gaps are marked in the findings.

## Workstream verdict

Nothing here blocks a fresh macOS apply. Every rendered file parses under both
the nix and the Apple copies of its shell, first, second and third applies into
an isolated destination converge with no prompts and no removals, a `$HOME`
containing a space survives every context I tried, and login and non-login
paths reach identical state.

The Linux reviewer's worst finding does not exist here. A5-001, where
`ssh host command` gets none of the environment because Arch builds bash
without `SSH_SOURCE_BASHRC`, has no macOS counterpart. zsh is the login shell,
so sshd runs `zsh -c` and `~/.zshenv` builds PATH. Both macOS bashes are
compiled with `SSH_SOURCE_BASHRC` anyway, so even a user who ran `chsh` to bash
would be covered. No `chsh` step belongs in the macOS runbook.

Three things are worth fixing before deployment.

The daily shell is in emacs keymap. `dot_inputrc` sets `editing-mode vi` and a
25ms `keyseq-timeout` for bash, and the Linux host gets vi mode in zsh by
accident because zsh reads "vi" out of `EDITOR=nvim`. On macOS nix-darwin's
`/etc/zshrc` runs `bindkey -e` first, and nothing in the repo takes it back.
So bash is vi, zsh is emacs, on the same machine, and the shell you actually
live in is the one that lost.

Interactive zsh takes 1.05 seconds to start, against 0.42 without the system
rc. nix-darwin runs a global `compinit` before `~/.zshrc` runs its own, the two
see different `fpath` values, and `~/.zcompdump` is rewritten on every single
shell. The "only rebuild the dump if it's more than a day old" branch in
`dot_zshrc.tmpl` never gets a chance to help.

`keychain` throws away Apple's ssh-agent every time. macOS supplies an agent
through launchd and sets only `SSH_AUTH_SOCK`, never `SSH_AGENT_PID`; keychain
reads a socket with no PID as forwarded, refuses it, and spawns its own. The
key here has a passphrase and `~/.ssh/config` says `UseKeychain yes`, so this
trades a Keychain-backed unlock for a passphrase prompt at the first terminal
after every boot.

The rest are smaller: an alias that breaks on a source path containing a space,
a locale probe whose validity check cannot fail on macOS, and a Docker default
that puts every container on the machine into emulation.

## Startup file matrix

What each context actually reads, verified on the review host. The
`path_helper` column matters because the whole two-stage PATH design exists for
it.

| Context | Files read | PATH built | `path_helper` runs | `extras.sh` |
| --- | --- | --- | --- | --- |
| interactive login zsh (Terminal, Ghostty) | `/etc/zshenv`, `.zshenv`, `/etc/zprofile`, `.zprofile`, `/etc/zshrc`, `.zshrc` | `.zshrc` | no, see A5M-006 | yes |
| interactive non-login zsh | `/etc/zshenv`, `.zshenv`, `/etc/zshrc`, `.zshrc` | `.zshrc` | no | yes |
| non-interactive zsh (`zsh -c`) | `/etc/zshenv`, `.zshenv` | `.zshenv` | no | no |
| non-interactive login zsh (`zsh -lc`) | `/etc/zshenv`, `.zshenv`, `/etc/zprofile`, `.zprofile` | `.zshenv` | on stock macOS only, and it wins | no |
| `ssh host cmd` (login shell zsh) | `/etc/zshenv`, `.zshenv` | `.zshenv` | no | no |
| `ssh host cmd` (login shell bash) | `.bashrc`, via `SSH_SOURCE_BASHRC` | `.bashrc` | no | no |
| interactive bash, handoff on | `.bashrc`, then execs zsh | `.zshrc` | no | yes |
| login bash | `/etc/profile`, `.bash_profile`, `.bashrc` | `.bashrc` | yes, before the build | yes |
| `sh -l` | `/etc/profile`, `.profile` | `.profile` | yes, before the build | no |
| cron (`/bin/sh -c`) | none | no | no | no |
| launchd job or GUI app | none | no | no | no |
| git hook | none | no | no | no |

The last three rows are the same gap the Linux reviewer recorded as A5-007, and
`docs/shell-startup.md:32-38` names launchd specifically. See A5M-010.

## PATH order

Verified with `env -i HOME=... PATH=/usr/bin:/bin zsh -c` against a sandbox
`$HOME` with every candidate directory created. Directories that do not exist
are skipped.

1. `$GOPATH/bin`
2. `$XDG_DATA_HOME/mise/shims`
3. `~/.local/bin`
4. `~/.cargo/bin`
5. `$BUN_INSTALL/bin`
6. `~/.rd/bin`
7. `~/.config/emacs/bin`
8. `~/.nix-profile/bin`, `/run/current-system/sw/bin`, `/nix/var/nix/profiles/default/bin`
9. `/opt/homebrew/bin`, `/opt/homebrew/sbin`, untested, see A5M-007
10. everything inherited, minus anything already listed
11. `~/.pixi/bin`, `/Applications/Obsidian.app/Contents/MacOS`

Re-sourcing `~/.zshrc` inside a live shell leaves PATH byte-identical, so the
first-occurrence-wins rule holds. `MANPATH` is still the exception and still
grows, which is A5-008 and reproduces here unchanged.

Two macOS-specific notes on this list. `/etc/zshenv` sources nix-darwin's
`set-environment`, which sets PATH to the nix profiles plus the standard system
directories, and it runs before `~/.zshenv`, so the repo's build always sits on
top of a populated PATH rather than a bare one. And `mise activate` prepends
the real install directories ahead of the shims at every prompt, so listing the
shims at position 2 does not shadow anything; `mise doctor` reports no problems
inside a shell started from the rendered `~/.zshrc`. I checked that
specifically because the ordering comment in `shell-path.sh` invites the
question.

`/Applications/Obsidian.app/Contents/MacOS` holds `Obsidian` and
`obsidian-cli`. It sits last, so it shadows nothing, and the `[ -d ]` guard
covers a host without Obsidian. No finding.

## What macOS adds that Linux does not

`~/.zshrc` on this platform is the second half of a pair. `/etc/zshrc` runs
first, and on a nix-darwin host it is not Apple's file.

| Setting | Stock Apple `/etc/zshrc` | nix-darwin `/etc/zshrc` | This repo | Effect |
| --- | --- | --- | --- | --- |
| `HISTFILE` | `~/.zsh_history` | `~/.zsh_history` | unset | A5M-003 |
| `HISTSIZE` / `SAVEHIST` | 2000 / 1000 | 2000 / 2000 | unset | A5M-003 |
| `SHARE_HISTORY` | off | on | unset | A5M-003 |
| keymap | none, so `EDITOR` decides | `bindkey -e` | unset | A5M-002 |
| `compinit` | not run | run globally | run again | A5M-001 |
| `path_helper` (via `/etc/zprofile`) | run | not run | assumes it runs | A5M-006 |
| `LANG` fallback (via `/etc/zprofile`) | `C.UTF-8` if empty | not set | own probe | A5M-004 |
| `setopt BEEP` | on | off | unset | cosmetic |

The repo declares none of these, so on macOS they are inherited rather than
chosen, and the inherited values change when nix-darwin activates. That
activation is step 6 of the cold-start sequence in the plan, which means the
shell a user meets on their first login is not the shell they keep.

## Findings

### A5M-001

Finding ID: A5M-001

Severity: medium

Platform and scenario: macOS after nix-darwin activation, every interactive
zsh

Deployment phase: Post-apply, daily use

Files and lines: `dot_zshrc.tmpl:11-23`, `/etc/zshrc:23` (nix-darwin
generated), `nix/flake.nix` (no `programs.zsh` block)

Observed behavior: nix-darwin's `/etc/zshrc` runs `autoload -U compinit &&
compinit` before `~/.zshrc` is read. `~/.zshrc` then adds
`$XDG_DATA_HOME/zsh/site-functions` to `fpath` and runs `compinit` again. The
two calls see different `fpath` values, 10 entries against 11, so the second
one cannot reuse the dump the first just wrote and rebuilds it. `~/.zcompdump`
is therefore rewritten on every interactive shell. The `(N.mh+24)` freshness
check at `dot_zshrc.tmpl:19` always finds a dump written seconds ago and always
takes the `compinit -C` branch, so the cache the repo built never does
anything.

Fresh-host consequence: Interactive zsh startup is 1.05s. With the system rc
suppressed it is 0.42s, and a system-rc-only shell is 0.22s, so roughly 0.4s
per terminal is the rebuild alone. Every new pane, split and `zsh` invocation
pays it, and each one writes a 66KB file to `$HOME`.

Reproduction or evidence:

```bash
for i in 1 2 3; do
  b=$(/usr/bin/stat -f '%m' ~/.zcompdump); sleep 1.1
  zsh -ic true; a=$(/usr/bin/stat -f '%m' ~/.zcompdump)
  echo "$b -> $a"
done
# 1788454310 -> 1788454321   REWRITTEN
# 1788454321 -> 1788454323   REWRITTEN
# 1788454323 -> 1788454325   REWRITTEN

NOSYSZSHRC=1 zsh -ic true   # ~/.zcompdump mtime unchanged

/usr/bin/time -p zsh -ic true                  # real 1.05
/usr/bin/time -p env NOSYSZSHRC=1 zsh -ic true # real 0.42
/usr/bin/time -p env ZDOTDIR=/nonexistent zsh -ic true  # real 0.22

zsh -ic 'echo ${#fpath}'                       # 11
env ZDOTDIR=/nonexistent zsh -ic 'echo ${#fpath}'  # 10
```

Automated or manual: Automated defect

Current workaround: None in the repo.

Recommended change: Set `programs.zsh.enableGlobalCompInit = false;` in
`nix/flake.nix` and let `~/.zshrc` own completion startup, which is what the
comment at `dot_zshrc.tmpl:13-14` already assumes. That file belongs to Agent 2,
so the change needs their sign-off, but the defect is in this workstream's
behavior. The alternative, moving the `fpath` line into `~/.zshenv` so both
`compinit` calls agree, only halves the cost and leaves two of them running.

Verification: `~/.zcompdump` keeps its mtime across three consecutive
`zsh -ic true` runs, and `/usr/bin/time -p zsh -ic true` drops to roughly 0.4s.

Confidence: verified

### A5M-002

Finding ID: A5M-002

Severity: high

Platform and scenario: macOS after nix-darwin activation, every interactive
zsh

Deployment phase: Post-apply, daily use

Files and lines: `dot_zshrc.tmpl` (no `bindkey -v`), `dot_inputrc:1-11`,
`/etc/zshrc:13` (nix-darwin generated)

Observed behavior: nix-darwin's `/etc/zshrc` runs `bindkey -e`, which pins the
main keymap to emacs before `~/.zshrc` is read. Nothing in the repo sets
`bindkey -v`, so zsh stays in emacs mode. Bash on the same host reads
`~/.inputrc` and is in vi mode. Apple's stock `/etc/zshrc` does not call
`bindkey`, so a host that has not activated nix-darwin yet gets viins from the
`EDITOR=nvim` heuristic instead, which is the Linux behavior recorded as
A5-010. The keymap therefore flips from vi to emacs at first activation.

Fresh-host consequence: The daily shell has emacs keybindings on the primary
machine while bash, Vim, Neovim and the Linux host all have vi. `dot_inputrc`
went to the trouble of cutting `keyseq-timeout` to 25ms so that Esc leaves
insert mode without a lag, and that work does not reach zsh at all. Starship's
`character` module shows its `vimcmd_symbol` only in vi command mode, so the
mode indicator the `dot_inputrc:9-10` comment credits to starship is dead on
macOS. Nothing errors, which is why this survives.

Reproduction or evidence:

```bash
zsh -ic 'bindkey -lL main'                    # bindkey -A emacs main
env NOSYSZSHRC=1 zsh -ic 'bindkey -lL main'   # bindkey -A viins main
bash -ic 'bind -v | grep editing-mode'        # set editing-mode vi
grep -n bindkey /etc/zshrc                    # 13:bindkey -e
grep -rn 'bindkey' dot_zshrc.tmpl             # no match
```

Automated or manual: Automated defect

Current workaround: `bindkey -v` in `~/.config/shell/extras.sh`, which is
sourced late enough in `shell-interactive.sh` to win.

Recommended change: Add `bindkey -v` and `KEYTIMEOUT=2` to `dot_zshrc.tmpl`
next to the other zsh-only settings, with a comment naming the `dot_inputrc`
lines they mirror. This is the same fix A5-009 and A5-010 ask for on Linux, and
one edit closes all three. Making it explicit also stops the keymap depending
on the spelling of `EDITOR`.

Verification: `zsh -ic 'bindkey -lL main'` reports `viins` on both platforms,
and `zsh -ic 'echo $KEYTIMEOUT'` returns 2.

Confidence: verified

### A5M-003

Finding ID: A5M-003

Severity: medium

Platform and scenario: macOS, every interactive zsh

Deployment phase: Post-apply, daily use

Files and lines: `dot_zshrc.tmpl` (no history block), `dot_bashrc.tmpl:33-40`
for the contrast, `/etc/zshrc:9-13` (nix-darwin generated)

Observed behavior: The Linux reviewer found zsh with no history at all (A5-002).
On macOS the same repo produces a working history, because `/etc/zshrc` sets
`HISTFILE=$HOME/.zsh_history`, `HISTSIZE=2000`, `SAVEHIST=2000` and
`setopt HIST_IGNORE_DUPS SHARE_HISTORY HIST_FCNTL_LOCK`. Stock Apple's version
of the same file sets `SAVEHIST=1000` and no `SHARE_HISTORY`. The repo declares
none of it, so the behavior is whatever the platform happens to supply and it
changes at nix-darwin activation.

Fresh-host consequence: zsh keeps 2000 lines against bash's 100000, in
`~/.zsh_history` rather than under `$XDG_STATE_HOME` where the repo puts other
state, with `SHARE_HISTORY` on, which the repo never chose and which makes
every pane interleave into one stream. The comment at `dot_bashrc.tmpl:35`
saying "atuin owns history in both shells" is as inaccurate here as it is on
Linux, but the symptom is different enough that a fix tested on one platform
proves nothing about the other.

Reproduction or evidence:

```bash
zsh -ic 'echo "$HISTFILE $HISTSIZE $SAVEHIST"'
# /Users/evelynking/.zsh_history 2000 2000
env NOSYSZSHRC=1 zsh -ic 'echo "${HISTFILE:-UNSET} $HISTSIZE $SAVEHIST"'
# UNSET 30 0
wc -l ~/.zsh_history        # 2026, sitting at the cap
grep -n 'HISTSIZE\|SAVEHIST\|SHARE_HISTORY' /etc/zshrc
```

Automated or manual: Automated defect

Current workaround: None needed for basic recall; the numbers are just small.

Recommended change: The history block A5-002 asks for on Linux fixes macOS too
and takes the decision back from `/etc/zshrc`. Set
`HISTFILE="$XDG_STATE_HOME/zsh/history"`, `HISTSIZE=100000`, `SAVEHIST=100000`
and `setopt APPEND_HISTORY HIST_IGNORE_ALL_DUPS`, plus an explicit
`unsetopt SHARE_HISTORY` if the interleaving is not wanted. It belongs in
`dot_zshrc.tmpl`, not in the shared POSIX body.

Verification: `zsh -ic 'echo $SAVEHIST'` returns 100000 on both platforms and
the file lands under `$XDG_STATE_HOME`.

Confidence: verified

### A5M-004

Finding ID: A5M-004

Severity: medium

Platform and scenario: macOS, any shell that inherits a locale from a Linux
client, and any shell started from a bare environment

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh:21-35`

Observed behavior: The probe keeps an inherited `LANG` when
`LC_ALL="$LANG" locale charmap` succeeds. On macOS that command exits 0 for any
string. Given a locale the system does not have, it prints `US-ASCII` and
returns success, so the guard never fires and the bad value is exported
unchanged. The comment above the block gives "macOS and Linux do not guarantee
the same spelling" as the reason the probe exists, and that is exactly the case
it cannot detect on macOS. Separately, when nothing is inherited the probe
picks `C.UTF-8`, which macOS 26 does have, while the desktop session runs
`en_US.UTF-8`.

Fresh-host consequence: macOS sshd ships `AcceptEnv LANG LC_*` and macOS ssh
ships `SendEnv LANG LC_*`, both in the stock configuration, so a client's
locale arrives on every connection. A glibc-spelled value such as
`en_US.utf8` is accepted here and silently degrades the session to US-ASCII:
`sort` returns `A B a b` instead of `a A b B`, and anything non-ASCII stops
round-tripping. The `C.UTF-8` half is the macOS instance of A5-003 and splits
the same way, with `date '+%x'` giving `09/03/2026` locally and `09/03/26` over
SSH. Both are quiet, which is what makes them expensive to debug later.

Reproduction or evidence:

```bash
LC_ALL=xx_YY.UTF-8 locale charmap; echo $?     # US-ASCII, 0
env -i HOME=$H PATH=/usr/bin:/bin LANG=en_US.utf8 zsh -c 'echo $LANG'
# en_US.utf8   (kept; invalid on macOS)
env -i HOME=$H PATH=/usr/bin:/bin zsh -c 'echo $LANG'
# C.UTF-8      (desktop session is en_US.UTF-8)

printf 'b\na\nB\nA\n' | env -i PATH=/usr/bin:/bin LANG=en_US.UTF-8 sort | tr '\n' ' '
# a A b B
printf 'b\na\nB\nA\n' | env -i PATH=/usr/bin:/bin LANG=en_US.utf8 sort | tr '\n' ' '
# A B a b

grep -rn AcceptEnv /etc/ssh/sshd_config.d/    # 100-macos.conf: AcceptEnv LANG LC_*
```

Automated or manual: Automated defect

Current workaround: None in the repo.

Recommended change: Test the locale against the list the system admits rather
than against an exit status: `locale -a | grep -qx "$LANG"` works on macOS and
on glibc, where `locale -a` also lists the generated locales. Keep the existing
`locale charmap` call as a second gate if you want to catch a locale that is
listed but broken. For the default, macOS has no `/etc/locale.conf` for the fix
A5-003 recommends; `defaults read -g AppleLocale` returns `en_US` here and is
the closest equivalent, so the platform branch has to differ.

Verification: `env -i ... LANG=en_US.utf8 zsh -c 'echo $LANG'` returns a locale
the host actually has.

Confidence: verified

### A5M-005

Finding ID: A5M-005

Severity: medium

Platform and scenario: macOS, every local interactive shell

Deployment phase: Post-apply, first shell after each boot

Files and lines: `.chezmoitemplates/shell-interactive.sh:19-35`

Observed behavior: macOS runs an ssh-agent through launchd and hands the
session `SSH_AUTH_SOCK=/var/run/com.apple.launchd.*/Listeners`. It never sets
`SSH_AGENT_PID`. The repo's forwarded-agent branch only accepts a socket
matching `/tmp/ssh-*/agent.*` and only when `SSH_CONNECTION` is set, so locally
it always falls through to keychain. keychain then rejects the inherited socket
in `ssh_envcheck`, which requires a live `SSH_AGENT_PID` before it will treat a
socket as a local agent, classifies it as forwarded, and spawns its own. This
is not the theoretical case A5-014 describes on Linux, where the desktop agents
were installed but disabled. On macOS the launchd agent is always present and
is always discarded.

Fresh-host consequence: `~/.ssh/config` here sets `UseKeychain yes` and
`AddKeysToAgent yes`, and `~/.ssh/id_ed25519` has a passphrase. keychain 2.9.8
calls plain `ssh-add` with no `--apple-use-keychain`, so it cannot read the
passphrase macOS stored in the login Keychain and prompts instead. That prompt
is the first thing a new terminal does after a reboot and it blocks startup
until it is answered or cancelled. On the review host the shell's
`SSH_AUTH_SOCK` is keychain's while launchd's is untouched, so the two agents
coexist and only one of them holds the key.

Reproduction or evidence:

```bash
launchctl getenv SSH_AUTH_SOCK   # /var/run/com.apple.launchd.Exj8GYndFQ/Listeners
echo "$SSH_AUTH_SOCK"            # /Users/evelynking/.ssh/agent/s.Kbn1JEFjsu.agent.6Q7obBlYsO
launchctl list | grep ssh        # com.openssh.ssh-agent

env -i HOME=/tmp/fresh PATH="$PATH" \
  SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK)" \
  keychain --eval --noask --ignore-missing --debug id_ed25519
#  debug> Ignoring SSH_AUTH_SOCK -- this is a forwarded socket
#  * Starting ssh-agent...

grep -n 'ssh-add ${ssh_timeout}' "$(command -v keychain)"   # no --apple-use-keychain
```

Automated or manual: Undocumented manual step, the passphrase prompt

Current workaround: Add `--ssh-allow-forwarded` to the keychain call, or set
`SSH_AUTH_SOCK` back by hand.

Recommended change: The fix A5-014 proposes covers this too, and covers it
better here because the macOS case is concrete. Probe `ssh-add -l` against
whatever `SSH_AUTH_SOCK` already names, accept it when the agent answers, and
run keychain only when it does not. That keeps the forwarded case working,
keeps Apple's agent on macOS, and drops the socket-path pattern match. If
keychain has to stay in the local path on macOS, it needs
`--ssh-allow-forwarded` so it will inherit a PID-less socket. Either way the
passphrase prompt belongs in the manual-state inventory.

Verification: A new terminal reports `launchctl getenv SSH_AUTH_SOCK` and
`$SSH_AUTH_SOCK` as the same path, and no passphrase prompt appears after a
reboot when the key is in the login Keychain.

Confidence: verified for the mechanism, likely for the reboot prompt, which I
did not reproduce because it needs a boot with an empty agent

### A5M-006

Finding ID: A5M-006

Severity: medium

Platform and scenario: macOS, source checkout whose path contains a space

Deployment phase: Post-apply, running the documented system update

Files and lines: `.chezmoitemplates/shell-interactive.sh:107`, against
`:113-118` for the Linux branch that does it correctly

Observed behavior: The Darwin branch renders
`alias nix-switch='sudo darwin-rebuild switch --flake {{ .chezmoi.sourceDir }}/nix#macbook'`
with the path interpolated bare. The Linux branch four lines below builds the
same kind of path with `{{ ... | quote }}`. Rendering from a source directory
containing a space produces an alias whose flake argument splits in two.

Fresh-host consequence: `nix-switch` calls `darwin-rebuild switch --flake
/some/space test/nix#macbook`, which arrives as four arguments rather than
three. `darwin-rebuild` gets a flake reference that does not exist plus a
stray positional. The alias is the command `run_after_darwin-rebuild.sh`
tells the user to run when it detects drift, so the failure lands at exactly
the moment the repo is asking for a system rebuild. `mup` on the same branch
takes no path and is unaffected.

Reproduction or evidence:

```bash
chezmoi execute-template --source "/tmp/space test" --file dot_zshrc.tmpl |
  grep nix-switch
# alias nix-switch='sudo darwin-rebuild switch --flake /tmp/space test/nix#macbook'

# with darwin-rebuild and sudo stubbed to print their argv:
argc=4
  $1=[switch]
  $2=[--flake]
  $3=[/tmp/space]
  $4=[test/nix#macbook]
```

Automated or manual: Automated defect

Current workaround: Keep the checkout on a path without spaces, which the
default `~/.local/share/chezmoi` satisfies.

Recommended change: `{{ printf "%s/nix#macbook" .chezmoi.sourceDir | quote }}`,
matching what the Linux branch already does with `mise_config_dir`. Nothing
else in this workstream mishandles spaces; I checked a `$HOME` containing one
across interactive zsh, non-interactive zsh, interactive bash and the SSH bash
path, and PATH, `GOPATH`, `MANPATH` and `TMPDIR` all survive intact.

Verification: Render from a path with a space and confirm the alias body has
the flake reference in single quotes.

Confidence: verified

### A5M-007

Finding ID: A5M-007

Severity: low

Platform and scenario: macOS, non-interactive login zsh, and the design
rationale generally

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-path.sh:1-5`,
`.chezmoitemplates/shell-env.sh:92-103`, `docs/shell-startup.md:26-38`

Observed behavior: Two things are off here, in opposite directions. The
documentation says `path_helper` runs from `/etc/zprofile`, and after
nix-darwin activation it does not: nix-darwin replaces that file and the
generated copy has no `path_helper` call at all. `/etc/profile` is still
Apple's and still calls it, so the bash and `sh` login paths behave as
documented and the zsh login path does not. Going the other way, the one
context where `path_helper` genuinely does defeat the design is a
non-interactive login zsh on a host that has not activated nix-darwin yet.
`~/.zshenv` builds PATH, `/etc/zprofile` then runs `path_helper`, and no
`~/.zshrc` follows to rebuild it.

Fresh-host consequence: `zsh -lc 'cmd'` on a stock Mac gets `/usr/bin` and the
rest of the system directories ahead of the mise shims, the nix profiles and
`~/.local/bin`, so `python3` resolves to Apple's rather than the pinned one.
Anything that shells out with an explicit login shell hits this, which in
practice means editor and GUI-app PATH discovery helpers. It disappears once
nix-darwin activates, so the exposure is the window between first apply and
first activation, plus any host that never activates. The documentation error
costs nothing at runtime but sends the next reader to the wrong file.

Reproduction or evidence:

```bash
cat /etc/zprofile                      # nix-darwin's: no path_helper
cat /etc/zprofile.before-nix-darwin    # Apple's: eval `/usr/libexec/path_helper -s`
cat /etc/profile                       # still Apple's, still calls it

# stock-macOS simulation, .zshenv builds then path_helper reorders:
env -i HOME=$H PATH=/usr/bin:/bin zsh -c '
  eval $(/usr/libexec/path_helper -s); printf "%s\n" ${(s.:.)PATH}' | head -6
# /usr/local/bin
# /System/Cryptexes/App/usr/bin
# /usr/bin
# /bin
# /usr/sbin
# /sbin
```

Automated or manual: Documentation defect plus a narrow behavioral gap

Current workaround: None needed for interactive use.

Recommended change: Correct `docs/shell-startup.md:28-30` and the header of
`shell-path.sh` to say that `path_helper` runs from `/etc/profile` always and
from `/etc/zprofile` only before nix-darwin replaces it. If the `zsh -lc` case
matters, the fix is to drop the `case $-` guard in `shell-env.sh` and always
build in `~/.zshenv`, since the body is idempotent and `~/.zshrc` would rebuild
after `path_helper` anyway. That is a bigger change than the gap justifies, so
recording the limitation may be the better answer.

Verification: Reading, plus `zsh -lc 'echo $PATH'` on a stock Mac.

Confidence: verified

### A5M-008

Finding ID: A5M-008

Severity: medium

Platform and scenario: macOS, every container build and run

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh:61-66`

Observed behavior: `DOCKER_DEFAULT_PLATFORM=linux/amd64` is exported
unconditionally on Darwin, from `~/.zshenv`, so it reaches non-interactive
shells too. The comment gives the reason as "Apple silicon runs amd64 images
under emulation rather than failing to find a matching manifest", which is
true, but the variable applies to every image, not only the ones without an
arm64 manifest.

Fresh-host consequence: Every `docker pull`, `docker run` and `docker build`
selects amd64 even when a native arm64 image exists, so the whole container
workflow runs under emulation on a machine that could run it natively.
`docker build` also produces amd64 images, which is a correctness difference
rather than a speed one if the output is meant for local use. Because the
export sits in the shared env file, it also reaches CI-style non-interactive
invocations. The tradeoff being made is a permanent slowdown in exchange for
avoiding an occasional "no matching manifest" error that names its own fix.

Reproduction or evidence:

```bash
env -i HOME=$H PATH=/usr/bin:/bin zsh -c 'echo $DOCKER_DEFAULT_PLATFORM'
# linux/amd64
command -v docker    # ~/.rd/bin/docker, Rancher Desktop
```

I could not measure the runtime cost: the Rancher Desktop daemon is not running
on the review host, so `docker info` fails and no image could be pulled.

Automated or manual: Deliberate setting with a wider effect than its comment
claims

Current workaround: `DOCKER_DEFAULT_PLATFORM= docker run ...` per command, or
`--platform linux/arm64`.

Recommended change: This is a policy call for the owner rather than a bug.
Dropping the variable and passing `--platform linux/amd64` on the images that
need it keeps everything else native. If it stays, the comment should say that
it forces emulation for all images including native ones, so the next reader
knows what it costs.

Verification: With the variable unset, `docker run --rm alpine uname -m`
reports `aarch64`.

Confidence: verified for the setting, likely for the consequence

### A5M-009

Finding ID: A5M-009

Severity: low

Platform and scenario: macOS, Homebrew installation during cold start

Deployment phase: Prerequisite installation, then second apply

Files and lines: `dot_zprofile`, `.chezmoitemplates/shell-path.sh:23-27,50`

Observed behavior: The repo manages `~/.zprofile` as a two-line comment. The
Homebrew installer finishes by telling the user to append
`eval "$(/opt/homebrew/bin/brew shellenv)"` to that exact file. Doing so and
then running `chezmoi apply` produces a prompt, `.zprofile has changed since
chezmoi last wrote it?`, and accepting it reverts the edit. `shell-path.sh`
lists `/opt/homebrew/bin` and `/opt/homebrew/sbin` directly and its comment
explains why `brew shellenv` must not run, so the revert is the intended
outcome. What no file sets is `HOMEBREW_PREFIX`, `HOMEBREW_CELLAR`,
`HOMEBREW_REPOSITORY` or `INFOPATH`, which `brew shellenv` would also have
exported.

Fresh-host consequence: A user following the installer's own closing
instructions creates a conflict with chezmoi on the next apply, at the point in
the cold start where they are least likely to know which side is right. `brew`
itself works without the variables, so nothing breaks, but any script or
formula that reads `$HOMEBREW_PREFIX` gets an empty value.

Reproduction or evidence:

```bash
printf '\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> "$rd/home/.zprofile"
chezmoi --destination "$rd/home" --persistent-state "$rd/state.db" apply
# .zprofile has changed since chezmoi last wrote it?
```

Homebrew is not installed on the review host, so I could not verify the
position of `/opt/homebrew/bin` in a live PATH or confirm that nothing else
needs `brew shellenv`. A cold-start host has to check both.

Automated or manual: Ownership conflict with a documented external installer

Current workaround: Skip the installer's final instruction.

Recommended change: Say in the macOS cold-start runbook that the Homebrew
installer's `.zprofile` step is deliberately skipped and why, and either set
the `HOMEBREW_*` variables in the Darwin branch of `shell-env.sh` or record
that they are intentionally absent. Extending `dot_zprofile`'s comment to name
Homebrew would put the answer where someone hitting the prompt will look.

Verification: A cold-start run reaches the second apply with no `.zprofile`
prompt.

Confidence: verified for the prompt, hypothesis for the `HOMEBREW_*` impact

### A5M-010

Finding ID: A5M-010

Severity: low

Platform and scenario: macOS, launchd jobs, GUI applications, cron and git
hooks

Deployment phase: Post-apply

Files and lines: `docs/shell-startup.md:32-38`,
`.chezmoitemplates/shell-env.sh:98-103`

Observed behavior: This is A5-007 with macOS mechanisms. The document and the
comment both claim the non-interactive build covers "SSH commands, cron and
launchd jobs, and git hooks". SSH commands are genuinely covered here, for both
possible login shells. The other three are not, and launchd is the furthest
from covered: it starts a program directly with no shell at all, so no startup
file is consulted under any configuration. macOS cron runs `/bin/sh -c`, which
reads nothing when non-interactive. Git runs hooks directly.

Fresh-host consequence: Nothing regresses that was not already broken. The cost
is the same as on Linux: the document tells a reader the problem is solved, so
the next "command not found" gets debugged in the wrong place. The macOS-only
part is that GUI applications inherit the launchd environment as well, and
`launchctl getenv PATH` is empty here, so an app launched from the Dock sees
only `/usr/bin:/bin:/usr/sbin:/sbin`. Nothing in the repo runs
`launchctl setenv`, which is the right call given how badly that ages, but it
does mean the AeroSpace `exec-and-forget` commands and any GUI editor's
subprocess PATH come from launchd rather than from here.

Reproduction or evidence:

```bash
env -i HOME=$H PATH=/usr/bin:/bin /bin/sh -c 'echo "$PATH"'
# /usr/bin:/bin
launchctl getenv PATH
# (empty)
```

Automated or manual: Documentation defect

Current workaround: None needed.

Recommended change: The narrowing A5-007 asks for, with the macOS specifics
named: launchd plists need their own `EnvironmentVariables` block, cron entries
need a `PATH=` line, and git hooks need an absolute path or a
`#!/usr/bin/env zsh` shebang. Worth saying explicitly that SSH commands are the
one item on the list that the mechanism does deliver, and that on macOS it
delivers for both zsh and bash login shells.

Verification: Reading.

Confidence: verified

### A5M-011

Finding ID: A5M-011

Severity: low

Platform and scenario: macOS, a caller that sets `TMPDIR` with a trailing slash

Deployment phase: Post-apply

Files and lines: `.chezmoitemplates/shell-env.sh:41-47`

Observed behavior: The guard replaces `TMPDIR` when it is empty, `/tmp` or
`/private/tmp`, and passes anything else through as a deliberate override. It
does not match `/tmp/` or `/private/tmp/`, which are the same generic locations
written with the trailing slash `getconf DARWIN_USER_TEMP_DIR` itself uses.

Fresh-host consequence: A shell that inherits `TMPDIR=/tmp/` keeps it, so the
Emacs daemon and `emacsclient` land in different directories and
`emacsclient -a ""` starts a second daemon instead of attaching. That is the
exact failure the block exists to prevent. The values that actually reach a
macOS shell in practice are the launchd per-user directory, which is preserved
correctly, and nothing at all over SSH, which is replaced correctly, so this is
narrow.

Reproduction or evidence:

```bash
for t in "" /tmp /private/tmp /tmp/ /private/tmp/; do
  printf '%-14s -> %s\n' "${t:-unset}" \
    "$(env -i HOME=$H PATH=/usr/bin:/bin ${t:+TMPDIR=$t} zsh -c 'echo $TMPDIR')"
done
# unset          -> /var/folders/01/.../T/
# /tmp           -> /var/folders/01/.../T/
# /private/tmp   -> /var/folders/01/.../T/
# /tmp/          -> /tmp/
# /private/tmp/  -> /private/tmp/
```

Automated or manual: Automated defect

Current workaround: None needed.

Recommended change: Strip a trailing slash before comparing, or match with a
`case` that accepts both forms.

Verification: The loop above replaces all four generic values.

Confidence: verified

## Linux findings confirmed unchanged on macOS

These reproduce here with the same evidence, so they are one cause each rather
than two. Listing them so the coordinator can merge rather than re-test.

| Finding | macOS result |
| --- | --- |
| A5-004, `extras.sh` unreachable non-interactively | `zsh -ic` gives 9999, `zsh -c` gives 8888 |
| A5-005, Jupyter variables clobber the inherited value | `7777 mine 0.0.0.0` in, `8888 jupyter 127.0.0.1` out, `MAMBA_ROOT_PREFIX` preserved |
| A5-007, cron and git hooks are not covered | see A5M-010 |
| A5-008, `MANPATH` grows on re-source | two copies after `source ~/.zshrc` |
| A5-012, `create_direnv_micromamba` does not quote the env name | same code path, no platform branch |
| A5-013, `.direnvrc` asks micromamba for the zsh hook | `micromamba shell hook` output for bash and zsh is byte-identical here too |

## Linux findings that do not apply here

A5-001, the SSH command environment gap, does not exist on macOS. zsh is the
login shell and reads `~/.zshenv` unconditionally, and both bashes on this host
are built with `SSH_SOURCE_BASHRC`, so `ssh host cmd` gets the full environment
either way. No `chsh` step belongs in the macOS runbook.

A5-016, the double startup from the bash-to-zsh handoff, does not fire, for the
same reason. Bash is only reached deliberately here, which is the fallback role
`dot_bashrc.tmpl:18-21` describes. I confirmed the handoff still works when
invoked, under both Apple's bash 3.2.57 and the nix bash 5.3.15.

A5-017, the leftover `~/Work` project root, is Omarchy's installer and has no
macOS equivalent. `~/Work` does not exist here.

A5-003 applies in substance, the `C.UTF-8` against `en_US.UTF-8` split, but its
recommended fix does not port: macOS has no `/etc/locale.conf`. Folded into
A5M-004.

A5-009 and A5-010, the zsh `KEYTIMEOUT` and `bindkey -v` gaps, apply with a
worse outcome here. Folded into A5M-002.

A5-002, no zsh history, does not reproduce: `/etc/zshrc` supplies one. The
underlying omission is the same and the fix is the same. See A5M-003.

## Manual state in this workstream

| Item | Status |
| --- | --- |
| keychain passphrase prompt at the first shell after boot | undocumented manual work, see A5M-005 |
| `mkdir -p ~/.config/shell` and write `extras.sh` | documented, README and `docs/shell-startup.md` |
| Homebrew installer's `.zprofile` instruction, to be skipped | undocumented, see A5M-009 |
| `micromamba create -n <name>` before `layout micromamba` works | manual; `layout_micromamba` only activates |
| SSH key restoration into `~/.ssh/id_ed25519`, and its Keychain entry | outside this workstream, Agent 7 |
| `chsh` | not required on macOS |
| Reboot or logout | not required by this workstream |

## What converges and what is intentionally unmanaged

Every file in this workstream renders, parses under both the nix and the Apple
copy of its shell, and converges. A real apply into an isolated destination
created `.bash_profile`, `.bashrc`, `.direnvrc`, `.inputrc`, `.profile`,
`.zprofile`, `.zshenv`, `.zshrc` and the `local-projects` tree with no prompts
and no removals, and the second and third applies produced no output at all.

`chezmoi status` on the review host reports `.zshrc`, `.bashrc`,
`.bash_profile` and `.zshenv` as modified and `.zprofile`, `.profile`,
`.inputrc` and `local-projects/.mise.toml` as pending. That is not drift: the
host is still on the pre-branch versions and has not applied since. I diffed
each one against `chezmoi cat` and every difference is a commit on this branch.
Nothing in this workstream rewrites a managed file at runtime.

`~/local-projects` already exists here with real user data in it. No source
directory in this repo carries the `exact_` prefix, so chezmoi adds
`.mise.toml` and `tries/` alongside the existing contents and removes nothing.
I checked that specifically because it would be the expensive kind of mistake.

Deliberately unmanaged, and correctly so:

- `~/.config/shell/extras.sh`. The fourteen sibling deletions in
  `.chezmoiremove` do not include it. Agent 7 owns whether those should expire.
- `~/.zcompdump`, though see A5M-001 for what currently writes it. `compaudit`
  is clean on this host, so the insecure-directories prompt did not trigger.
- `~/.zsh_history` and `~/.bash_history`, both written by their shells. The zsh
  one is created by `/etc/zshrc` rather than by anything in this repo, which is
  A5M-003.
- `~/.ssh/agent/`, where Apple's `ssh-agent` puts its socket. Not the repo's,
  and not cleaned by anything.

## Checks run

Static:

```bash
chezmoi execute-template --file dot_zshenv.tmpl  | zsh -n
chezmoi execute-template --file dot_zshenv.tmpl  | sh -n
chezmoi execute-template --file dot_zshrc.tmpl   | zsh -n
chezmoi execute-template --file dot_bashrc.tmpl  | bash -n
chezmoi execute-template --file dot_bashrc.tmpl  | /bin/bash -n   # Apple bash 3.2
chezmoi execute-template --file dot_profile.tmpl | sh -n
chezmoi execute-template --source "/tmp/space test" --file dot_zshrc.tmpl
chezmoi managed; chezmoi status
chezmoi --destination "$rd/home" --persistent-state "$rd/state.db" \
  apply --force --verbose --exclude=scripts,externals --refresh-externals=never
```

Behavioral, against rendered copies in a sandbox `$HOME` unless noted:

- non-interactive zsh, interactive zsh, and both with a minimal inherited PATH
- non-interactive bash with `SSH_CLIENT` set and unset, under Apple's 3.2.57
  and the nix 5.3.15, to settle whether A5-001 exists here
- login and non-login bash, and interactive and non-interactive login `sh`
- the bash-to-zsh handoff on, off with `SHELL_PREFER_ZSH=0`, and with no zsh
- `$HOME` containing a space, across four shell contexts, checking PATH,
  `GOPATH`, `MANPATH` and `TMPDIR`
- `path_helper` applied after the `~/.zshenv` build, to reproduce the stock
  macOS non-interactive login case
- PATH re-source idempotency, and `MANPATH` after one build and after two
- `TMPDIR` across six inherited values
- `LANG` across five inherited values, against `locale -a`, `locale charmap`
  exit status, `sort` collation and `date '+%x'`
- inherited `JUPYTER_*` and `MAMBA_ROOT_PREFIX`, checked for clobbering
- `extras.sh` reachability in interactive and non-interactive shells
- `bindkey -lL main` and `bind -v` under three system-rc conditions
- `HISTFILE`, `HISTSIZE`, `SAVEHIST` and the history options, same conditions
- `~/.zcompdump` mtime across consecutive shells, with and without the system
  rc, and `fpath` length under each
- `zsh -ic true` wall time, split across `zsh -f`, `--no-rcs`, system rc only,
  user rc only, and both
- `keychain --debug` against the live launchd socket, with `--noask`
- `mise doctor` inside a shell started from the rendered `~/.zshrc`, to check
  the shims against `mise activate` ordering
- `micromamba shell hook` output for bash and zsh, diffed
- a simulated Homebrew `.zprofile` append followed by an apply, with and
  without `--force`
- `darwin-rebuild` and `sudo` stubbed to print their argv, driving `nix-switch`
  from a source path containing a space

Read-only comparison against the system files this repo shares a shell with:
`/etc/zshenv`, `/etc/zprofile`, `/etc/zshrc`, `/etc/profile`, `/etc/bashrc` and
their `.before-nix-darwin` counterparts, `/etc/paths`, `/etc/paths.d/*`,
`/etc/ssh/sshd_config.d/100-macos.conf`, `/etc/ssh/ssh_config`, and
keychain 2.9.8's `ssh_envcheck`.

## Checks deferred

To a disposable cold-start Mac:

- first, second and third apply transcripts for these files on a stock host
- the whole sequence before nix-darwin activates, where `/etc/zprofile` and
  `/etc/zshrc` are still Apple's. Everything in the table under "What macOS
  adds" changes at that boundary and I could only read the stock files, not run
  under them.
- Homebrew's PATH position and whether anything needs the `HOMEBREW_*`
  variables, for A5M-009
- the keychain passphrase prompt on a real boot with an empty agent, for A5M-005
- shell startup before nix-darwin has installed atuin, starship, zoxide, fzf,
  eza, bat, fd and keychain. I could not simulate this: `/etc/zshenv` puts the
  nix profiles on PATH unconditionally, so every optional tool is always found
  on an activated host.
- `docker run --rm alpine uname -m` with and without
  `DOCKER_DEFAULT_PLATFORM`, for A5M-008

To Agent 2:

- `programs.zsh.enableGlobalCompInit = false` in `nix/flake.nix`, which is the
  fix for A5M-001 but lands in their file
- whether the flake should stop nix-darwin setting `bindkey -e` and history
  defaults at all, or whether the repo should just override them in
  `dot_zshrc.tmpl` as A5M-002 and A5M-003 recommend
