# Agent 2 deployment review: macOS and nix-darwin

Reviewed commit: `abb2e562c5f61d4904a636fe1645863a4feb7722`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-03

Local review host: macOS 26.6.2 (build 25G83), Apple Silicon T6020, hostname
`lagrange`, account `evelynking`, Determinate Nix 3.11.3 (Nix 2.31.2),
chezmoi 2.70.5, Ghostty 1.3.1, nix-darwin generation 8 active

Agents 1 and 3 through 7 reviewed `30923db`. `abb2e56` adds only their six
report files under `docs/`, so every code finding below applies to both
commits. I checked that with `git diff --stat 30923db..abb2e56`.

This is the first review in the set that ran on Apple Silicon. Agents 6 and 7
explicitly deferred macOS rendering, application behavior and privacy
approvals to this workstream.

## Workstream verdict

macOS is blocked, and not narrowly. Two independent faults each stop
`darwin-rebuild switch` before it does anything:

1. `nix/flake.nix:18` hardcodes `username = "evelyn"`. The account on the
   owner's own Mac is `evelynking`. nix-darwin checks the primary user with
   `id` and aborts activation with exit 2.
2. `terraform` is unfree (BSL 1.1) and the flake sets no
   `nixpkgs.config.allowUnfree`. The configuration cannot be evaluated at all,
   let alone built.

Neither is theoretical. The nix-darwin generation running on this machine was
built from a different configuration: its activation script carries
`primaryUser=evelynking` and contains no Homebrew step. So the flake in this
repository has never been activated anywhere, and the review host is
effectively a fresh-host test that has already failed.

The drift hook is what should have caught this, and it is the third problem.
It wraps the evaluation in `2>/dev/null` and exits 0 on any failure, so it
prints a reassuring nothing on every apply. Allowing unfree by hand and
rerunning the same hook reports that six of its seven compared outputs differ.
The one mechanism designed to tell you the system is stale is the mechanism
that hides it.

Three more findings are high. `homebrew.onActivation.cleanup = "uninstall"`
generates a Brewfile with no formulae at all and then runs
`brew bundle --force-cleanup`, which uninstalls every Homebrew formula, cask
and tap on the machine that is not in that list, without a prompt. Cask
installs abort outright when an application already sits at the target path,
and nix-darwin exposes no way to pass Homebrew's `--adopt`. And Homebrew
itself is an undocumented prerequisite whose absence is a red log line rather
than an error, so a fresh Mac can complete activation with zero GUI
applications installed.

What works: every Nix package resolves, is unbroken, and supports
`aarch64-darwin`. All 21 casks exist, none are Intel-only, and every macOS
minimum is 14 or lower against a host on 26.6.2. The rendered Ghostty config
passes `ghostty +validate-config` on 1.3.1. The AeroSpace config is valid
TOML on `config-version = 2`. An isolated dry-run apply of the file targets
is clean. The drift hook's comparison logic is correct once it can evaluate.

I did not run `darwin-rebuild switch`, install Homebrew, or install any cask
on this host. Those belong in the disposable cold-start stage.

## Reconstructed macOS bootstrap

The repo documents none of this. Steps marked "not in repo" have no mention in
`README.md` or `docs/package-lists/macos.md`.

| # | Step | Privilege | Source |
| --- | --- | --- | --- |
| 1 | Install Xcode Command Line Tools (`xcode-select --install`) | admin | not in repo |
| 2 | Install Determinate Nix | admin, creates the `/nix` APFS volume | not in repo |
| 3 | Install Homebrew | admin | `docs/package-lists/macos.md:32` says it "must already be installed", with no command and no ordering |
| 4 | Obtain chezmoi and this source tree, run `chezmoi init` | user | not in repo; `README.md:13-24` starts at `chezmoi apply` |
| 5 | First `chezmoi apply` | user | `README.md:16` |
| 6 | Edit `nix/flake.nix:18` to the real short account name | user | not in repo, and currently mandatory |
| 7 | First `darwin-rebuild switch --flake "$(chezmoi source-path)/nix#macbook"` | root | `docs/package-lists/macos.md:11` |
| 8 | Grant Accessibility to AeroSpace, launch it by hand | user, GUI approval | not in repo |
| 9 | Second `chezmoi apply`, now that Emacs and mise exist | user | not in repo |
| 10 | Log out and back in for the new shell and font set | user | not in repo |

Step 7 fails today at both `username` and `terraform`. Step 3 has no ordering
constraint stated, but it is load-bearing: Homebrew must exist before step 7
or the casks are silently skipped.

## Package ownership

No command is claimed by two owners. That part of the design holds up.

| Owner | Scope | Count |
| --- | --- | --- |
| `nix/flake.nix` `environment.systemPackages` | system CLI packages | 62 |
| `nix/flake.nix` `fonts.packages` | Nerd Fonts | 3 |
| `nix/flake.nix` `homebrew.casks` | GUI applications and `1password-cli` | 21 plus 1 tap |
| `dot_config/mise/conf.d/10-dotfiles.toml` | runtimes and global CLI tools | 4 runtimes, 20 tools |

Checked for collisions and found none. `bun` and `uv` are in Nix and are used
by mise as installers for its npm and pipx backends, which is the documented
intent rather than a duplicate. mise declares no `terraform`, `git`, `gnupg`
or `google-cloud-sdk`. Nix declares none of mise's runtimes.

Two ownership statements in the docs are wrong on macOS:

- `README.md:81-85` tells you to run `mise self-update`. Nix owns mise here.
- `README.md:32` says GUI apps come from Homebrew casks, which is true, but
  nothing says who installs Homebrew or when.

One live inconsistency, not a repo fault: `bun` on this host resolves to
`~/.bun/bin/bun` rather than the Nix copy, because `shell-path.sh:39-43`
ranks `$BUN_INSTALL/bin` above the Nix profiles. A leftover manual install
outranks the declared one.

## Nix package evaluation

Evaluated with the committed lock and no lock rewrite. Every package in
`environment.systemPackages`, checked for license, `broken`, and platform
support on `aarch64-darwin`:

| Result | Packages |
| --- | --- |
| free, unbroken, `aarch64-darwin` supported | 61 of 62 |
| unfree | `terraform` (`bsl11`) |
| broken | none |
| platform-excluded | none |

`nix flake check --no-write-lock-file` passes. It does not force the system
derivation, so it does not catch the unfree failure. `nix build --dry-run` does.

With unfree allowed by hand, a first activation would build 83 derivations and
fetch 120 paths, 1218.75 MiB compressed and 4018.33 MiB unpacked. Terraform is
in the built set rather than the fetched set, because the binary cache does not
carry unfree builds, so a fresh Mac compiles it from Go source.

## Homebrew casks

All 21 casks resolve against the Homebrew API today. The `nikitabobko/tap`
repository exists and its `aerospace` cask is at `0.21.3-Beta`.

| Property | Casks |
| --- | --- |
| Requires an admin password mid-activation (`pkg` artifact) | `adobe-acrobat-reader`, `basictex`, `ltspice` |
| Declares a macOS minimum above 12 | `adobe-acrobat-reader` (13), `chatgpt` (13), `ghostty` (13), `ltspice` (14) |
| Arch-restricted or Intel-only | none |
| Needs sign-in or an account before first use | `1password-cli`, `bitwarden`, `chatgpt`, `claude`, `raycast`, `spotify`, `zotero` |
| Runs a preflight step | `klayout` |
| Collides with an application already on this host | `bitwarden`, `firefox`, `ghostty`, `iterm2`, `obsidian`, `rancher`, `raycast`, `spotify`, `visual-studio-code` |

The last row is the interesting one and is finding A2-005.

## Drift hook behavior

`run_after_darwin-rebuild.sh.tmpl` runs on every apply. Tested against the live
system and against fixtures.

| Case | Result |
| --- | --- |
| `darwin-rebuild` absent | Exits 0 at the guard on line 14. Correct. |
| Evaluation fails (the current state of this repo) | Prints "cannot evaluate ... skipping the drift check", exits 0, reports no drift. |
| Evaluation succeeds, system drifted | Reports `packages, /etc, applications, fonts, launchd, activation` and prints the exact activation command. Correct. |
| Evaluation succeeds, `patches` output matches | Correctly omitted from the drift list, so per-output comparison works. |
| `/run/current-system` absent | `sed` fails to open the activation script, pipeline fails under `pipefail`, hook exits 1 and the apply stops. Confirms A1-003 on real macOS. Agent 1 saw exit 2 from a stub; on macOS it is 1. |
| Source path containing spaces | Safe. Line 12 quotes the assignment and every use is quoted. |

Warm evaluation takes 2.6 s. That runs on every `chezmoi apply`, which is
tolerable, but a cold evaluation after a lock bump is much longer and there is
no cache or skip.

All six symlinks the hook compares exist in the running generation, so the
comparison targets are right:

```text
sw                   -> /nix/store/pqayj2p...-system-path
etc                  -> /nix/store/vfnfxnw...-etc/etc
Applications         -> /nix/store/vdzpbqn...-system-applications/Applications
Library/Fonts        -> /nix/store/cphdh4l...-fonts/Library/Fonts
Library/LaunchAgents -> /nix/store/h2bsvlm...-launchd/Library/LaunchAgents
patches              -> /nix/store/6p63jjp...-patches/patches
```

## macOS manual state

Classified per the plan. "Undocumented" means absent from `README.md` and
`docs/package-lists/macos.md`.

| Item | Status |
| --- | --- |
| Xcode Command Line Tools | Undocumented manual |
| Determinate Nix install | Undocumented manual |
| Homebrew install | Documented as a precondition, no command, no ordering |
| First nix-darwin activation | Documented command, no bootstrap context |
| Editing `username` to match the account | Undocumented manual, currently mandatory |
| Admin password during cask `pkg` installs | Undocumented manual, three casks |
| AeroSpace Accessibility approval | Undocumented manual |
| Starting AeroSpace at all | Undocumented manual, `start-at-login = false` and no launchd agent |
| Raycast, Rancher Desktop and ChatGPT permission prompts | Undocumented manual |
| 1Password, Bitwarden, ChatGPT, Claude, Raycast, Spotify, Zotero sign-in | Undocumented manual |
| Adobe Acrobat Reader license acceptance | Undocumented manual |
| GPG secret key import and `pinentry-mac` Keychain prompt | Undocumented manual. `dot_config/git/config.tmpl:44` makes signing mandatory; agent 7 covers the policy, the Keychain half is macOS-only |
| Git credential helper `osxkeychain` first use | Automated, prompts on first push |
| Rosetta | Not required by anything declared |
| Logout or reboot for fonts and shell | Undocumented manual |
| macOS system defaults (key repeat, Dock, Finder) | Intentionally unmanaged; the flake sets no `system.defaults` |

## Findings

### A2-001

Finding ID: A2-001

Severity: blocker

Platform and scenario: Apple Silicon macOS, any account whose short name is
not literally `evelyn`, including the repository owner's own machine

Deployment phase: First nix-darwin activation

Files and lines: `nix/flake.nix:15-18`, `nix/flake.nix:26`,
`docs/package-lists/macos.md:34-35`

Observed behavior: `username` is a hardcoded literal `"evelyn"` and feeds
`system.primaryUser`. nix-darwin's generated activation script guards it with
`if ! id -- "$primaryUser"` and exits 2 with "primary user `evelyn` does not
exist, aborting activation". The Homebrew step in the same script runs
`sudo --preserve-env=PATH --user=evelyn --set-home env brew bundle`, so it
would fail on the same account name even if the guard were removed.

Fresh-host consequence: The first and every later `darwin-rebuild switch`
aborts. No system packages, no fonts, no casks. The user has a chezmoi apply
that appears to have succeeded and a system that has none of its tools.

Reproduction or evidence: `id -un` on this host returns `evelynking`.
`nix eval --raw '.#darwinConfigurations.macbook.config.system.primaryUser'`
returns `evelyn`. The guard is at lines 73-81 of the activation script in the
currently running generation, and the Homebrew `sudo --user=evelyn` line is at
line 570 of the activation script this flake produces. The generation actually
running on this host carries `primaryUser=evelynking`, so it came from a
different configuration and this flake has never activated here.

Automated or manual: Automated failure caused by an undocumented manual edit

Current workaround: Change line 18 to the real short account name before the
first activation.

Recommended change: Stop hardcoding it. Either key `darwinConfigurations` by
host and give each entry its own username, or accept the account name as a
flake argument the documented command passes. If it must stay a literal, say
so as step one of the macOS cold-start procedure rather than leaving it as a
comment inside the file.

Verification: On a disposable Apple Silicon host with a short name other than
`evelyn`, follow only the documented procedure and confirm the first
activation succeeds. Repeat with a second account name to confirm the fix is
not a second hardcoded value.

Confidence: verified

### A2-002

Finding ID: A2-002

Severity: blocker

Platform and scenario: Apple Silicon macOS, any host without a pre-existing
`allowUnfree` setting

Deployment phase: First nix-darwin activation, before any build

Files and lines: `nix/flake.nix:106`, `nix/flake.nix:20-27`

Observed behavior: `terraform` carries the BSL 1.1 license and nixpkgs refuses
to evaluate it. The flake sets no `nixpkgs.config.allowUnfree` and no
`allowUnfreePredicate`. Evaluation of the whole configuration therefore fails,
so nothing is built.

Fresh-host consequence: `darwin-rebuild switch` exits with an evaluation error
naming a package the user did not knowingly opt into. A first-time reader has
no reason to connect "Refusing to evaluate package 'terraform-1.15.9'" to a
policy setting they are expected to add.

Reproduction or evidence:
`nix build --dry-run --no-link --no-write-lock-file '.#darwinConfigurations.macbook.system'`
fails with "error: Refusing to evaluate package 'terraform-1.15.9' ... because
it has an unfree license (`bsl11`)". The same command with
`NIXPKGS_ALLOW_UNFREE=1 --impure` succeeds and plans 83 builds and 120
fetches. A per-package license sweep over all 62 entries found `terraform` to
be the only unfree one; nothing else is broken or platform-excluded.

Automated or manual: Automated

Current workaround: Export `NIXPKGS_ALLOW_UNFREE=1` for the activation, which
is impure and does not survive into the documented command.

Recommended change: Decide the policy and write it down. Either set
`nixpkgs.config.allowUnfreePredicate` for `terraform` alone, with a comment
saying why, or drop `terraform` and let mise or a container own it. A blanket
`allowUnfree = true` would work but silently widens what a future package
addition can pull in.

Verification: Run the plan's own
`nix build --dry-run --no-link "$flake#darwinConfigurations.macbook.system"`
with no environment overrides and confirm it plans a build. Add a second
unfree package and confirm the predicate rejects it if that is the intent.

Confidence: verified

### A2-003

Finding ID: A2-003

Severity: high

Platform and scenario: macOS, whenever the flake cannot be evaluated, which is
its current state on every host

Deployment phase: Every apply, after-script phase

Files and lines: `run_after_darwin-rebuild.sh.tmpl:20-32`,
`docs/package-lists/macos.md:37-42`

Observed behavior: The evaluation is wrapped in `2>/dev/null` and its failure
branch prints one line to stderr and exits 0. Any evaluation error, an unfree
package, a syntax error, a bad lock, a missing input, produces the same
message and the same success status. The hook then reports no drift.

Fresh-host consequence: The repo's stated mechanism for noticing an unactivated
or stale system is silent exactly when the system is most broken. On this host
it has been reporting nothing while the running generation differs from the
flake in six of its seven compared outputs.

Reproduction or evidence: Rendering the hook and running it live prints
"nix-darwin: cannot evaluate /Users/evelynking/.local/share/chezmoi/nix;
skipping the drift check." and exits 0. Rerunning the identical script with
`NIXPKGS_ALLOW_UNFREE=1` and `--impure` prints "the running system differs in
packages, /etc, applications, fonts, launchd, activation" and the activation
command. The logic is correct; only the error handling hides it.

Automated or manual: Automated

Current workaround: None. Nothing surfaces the suppressed error.

Recommended change: Separate "cannot evaluate" from "no drift". Print the
captured stderr rather than discarding it, and choose a non-zero exit or at
least a loud, distinguishable message when evaluation fails. A check that
cannot run is not a check that passed.

Verification: Force each failure class independently, an unfree package, a
syntax error, a deleted input, and confirm each produces a distinct message
naming the real cause. Then confirm the drifted and converged cases still
behave as they do today.

Confidence: verified

### A2-004

Finding ID: A2-004

Severity: high

Platform and scenario: macOS, any host with pre-existing Homebrew formulae,
casks or taps, which is the normal case for a machine being adopted rather
than built from stock

Deployment phase: First nix-darwin activation, Homebrew bundle step

Files and lines: `nix/flake.nix:143-147`, `nix/flake.nix:114-141`

Observed behavior: `cleanup = "uninstall"` makes nix-darwin append
`--force-cleanup` to `brew bundle`. The generated Brewfile lists one tap and
21 casks and no formulae at all. `brew bundle --force-cleanup` uninstalls
every formula, cask and tap Homebrew knows about that is not in that file, with
no prompt, because `--force` suppresses confirmation.

Fresh-host consequence: On a stock Mac this is harmless, since Homebrew has
nothing installed yet. On an adopted Mac it is a mass uninstall of the user's
entire Homebrew world on the first activation, triggered by a command whose
documented purpose is installing this repo's own applications. Anything the
user installs by hand later is removed on the next switch.

Reproduction or evidence: The generated Brewfile at
`/nix/store/bsap36nl9jlh5khyraqlwda1s231bgmk-Brewfile` contains `tap` and
`cask` lines only, no `brew` lines. The activation script line 570 runs
`brew bundle --file=<that> --force-cleanup`. nix-darwin's `homebrew.nix:196`
is what adds `--force-cleanup` for `cleanup = "uninstall"`. I did not run it;
Homebrew is not installed on this host.

Automated or manual: Automated and unconditional once Homebrew exists

Current workaround: Set `cleanup = "none"` before the first activation on a
machine that already uses Homebrew, then review what the Brewfile would remove.

Recommended change: Start at `cleanup = "check"`, which nix-darwin surfaces as
a system check listing what would be removed rather than removing it. Move to
`"uninstall"` only after the list is empty and the policy is written down. If
`"uninstall"` stays, say plainly in `docs/package-lists/macos.md` that Homebrew
is fully declarative and that anything installed by hand will be removed.

Verification: On a disposable Mac, install two unrelated formulae and one
unrelated cask, run the first activation, and record exactly what survives.
Repeat with `cleanup = "check"` and confirm it reports without removing.

Confidence: verified by inspection of the generated Brewfile and activation
command; the removal itself was not executed

### A2-005

Finding ID: A2-005

Severity: high

Platform and scenario: macOS, any host where an application already exists at
a cask's target path

Deployment phase: First nix-darwin activation, Homebrew bundle step

Files and lines: `nix/flake.nix:119-141`

Observed behavior: Homebrew refuses to install a cask over an existing
application. `Library/Homebrew/cask/artifact/moved.rb:140-142` raises a
`CaskError` reading "It seems there is already an App at ..." unless `force` or
`adopt` is set. `brew bundle` passes neither by default, and nix-darwin has no
option that does: `homebrew.caskArgs` exposes `appdir`, `require_sha`,
`no_quarantine`, `no_binaries`, `ignore_dependencies` and the various plugin
directories, but no `adopt`.

Fresh-host consequence: The activation script runs under `set -e` and the
Homebrew step is its last action, so a cask collision aborts activation at the
end with a Ruby error. On this host nine of the 21 casks would collide:
Bitwarden, Firefox, Ghostty, iTerm, Obsidian, Rancher Desktop, Raycast,
Spotify and Visual Studio Code all already sit in `/Applications` from
non-Homebrew installs.

Reproduction or evidence: Homebrew's own source carries the raise and the
`!force && !adopt` condition. `ls /Applications` on this host lists all nine
apps. nix-darwin's `homebrew.nix` caskArgs submodule at lines 325 onward has no
`adopt` field. The activation script's `set -e` is at line 5 and the bundle
call at line 570.

Automated or manual: Automated failure requiring undocumented manual recovery

Current workaround: Before the first activation, either move each colliding
app aside or run `brew install --cask --adopt <name>` for each one so Homebrew
takes ownership in place.

Recommended change: Document the adoption step as part of the macOS cold start,
listing which casks are likely to collide on a machine that is not stock. If
this repo is ever pointed at more than one existing Mac, a scripted
`--adopt` pass is worth more than a paragraph.

Verification: On a disposable Mac, drop a hand-downloaded Firefox into
`/Applications`, run the first activation, and record the exact failure and
the state of the remaining casks. Repeat after an `--adopt` pass.

Confidence: verified by source inspection and host inventory; the collision
was not executed, since installing Homebrew would change this host

### A2-006

Finding ID: A2-006

Severity: high

Platform and scenario: Stock Apple Silicon macOS with no Homebrew

Deployment phase: First nix-darwin activation

Files and lines: `nix/flake.nix:112-115`, `docs/package-lists/macos.md:29-32`,
`README.md:13-24`

Observed behavior: nix-darwin does not install Homebrew. Its generated step is
`if [ -f "/opt/homebrew/bin/brew" ]; then ... else` print a red "Homebrew is
not installed, skipping..." line `fi`. The else branch does not fail. The
documentation states the precondition in one sentence at the end of a
paragraph and never gives the command or the ordering.

Fresh-host consequence: Activation reports success. The user gets all 62 Nix
CLI packages and none of the 21 GUI applications, including AeroSpace, Ghostty
and the password managers. The only signal is one line in a long activation
log. Rerunning activation after installing Homebrew fixes it, but nothing tells
the user that is what happened.

Reproduction or evidence: `/opt/homebrew` and `/usr/local/Homebrew` do not
exist on this host, and `brew --version` produces nothing. The conditional and
its message are lines 568-573 of the activation script this flake generates.

Automated or manual: Undocumented manual prerequisite with a silent failure

Current workaround: Install Homebrew before the first activation, or notice the
skipped line and activate again afterwards.

Recommended change: Put the Homebrew installation in the macOS cold-start
procedure, before the first activation, with the command. Since the flake
declares casks, treat a missing Homebrew as a configuration error rather than
a skip: nix-darwin's `system.checks` is the place to fail early with a message
naming the install command.

Verification: On a stock Apple Silicon snapshot, follow only the documented
procedure and record whether any GUI application is installed at the end.

Confidence: verified

### A2-007

Finding ID: A2-007

Severity: medium

Platform and scenario: macOS with AeroSpace running

Deployment phase: Daily use after deployment

Files and lines: `dot_config/aerospace/aerospace.toml:33-36`,
`dot_config/aerospace/aerospace.toml:43-44`,
`dot_config/aerospace/aerospace.toml:46-54`,
`dot_config/aerospace/aerospace.toml:66-67`,
`dot_vim/plugin/keymaps.vim:38-41`, `docs/keybindings.md`

Observed behavior: `mode.main.binding` registers system-wide hotkeys on
`ctrl-h`, `ctrl-j`, `ctrl-k`, `ctrl-l`, `ctrl-1` through `ctrl-9`, `ctrl-tab`,
`ctrl-enter`, `ctrl-minus`, `ctrl-equal`, `ctrl-slash` and `ctrl-comma`.
Global hotkeys are delivered to AeroSpace before the focused application sees
them, and AeroSpace has no per-application exclusion. The same repository binds
`<C-h>`, `<C-j>`, `<C-k>` and `<C-l>` to window navigation in
`dot_vim/plugin/keymaps.vim`, and LazyVim binds them by default in Neovim.
`ctrl-l` and `ctrl-k` are also the standard readline and zle clear-screen and
kill-line keys.

Fresh-host consequence: On macOS the repo's own documented editor keymap
cannot work inside a terminal, and two everyday shell keys stop responding.
`docs/keybindings.md` documents `<C-h>` through `<C-l>` as shared Vim and
Neovim behavior and never mentions that AeroSpace takes them first.

Reproduction or evidence: Both files are in this repository and bind the same
four chords. AeroSpace's binding model has no application scope; the documented
escape is a binding mode, and the repo's only mode switch is
`ctrl-shift-semicolon`. I could not execute this: AeroSpace is not installed
here, because it is a cask and Homebrew is absent.

Automated or manual: Automated conflict between two managed files

Current workaround: Enter service mode, or use the arrow-key and leader
alternatives where they exist.

Recommended change: Move the AeroSpace bindings off bare `ctrl` to the
`alt` chords AeroSpace's own default config uses, which is exactly why that
default exists. If `ctrl` is deliberate, say so in `docs/keybindings.md` and
list the editor and shell keys it costs.

Verification: On a Mac with AeroSpace running and Accessibility granted, open
Neovim in Ghostty and press each of the four chords. Then press `ctrl-l` at a
zsh prompt.

Confidence: likely

### A2-008

Finding ID: A2-008

Severity: medium

Platform and scenario: Apple Silicon macOS, first login after deployment

Deployment phase: Post-activation, first session

Files and lines: `dot_config/aerospace/aerospace.toml:6`, `nix/flake.nix:150-159`

Observed behavior: `start-at-login = false`, and the flake declares no
`launchd` agent and no login item. Nothing in the repo starts AeroSpace.
AeroSpace also cannot manage windows at all until the user grants it
Accessibility in System Settings, which is a GUI approval no configuration can
automate. `automatically-unhide-macos-hidden-apps = true` depends on the same
approval.

Fresh-host consequence: After a complete, successful deployment the tiling
window manager is installed and configured and does nothing. The user has to
know to launch it and to find the Accessibility toggle. Neither step appears
anywhere in the repo.

Reproduction or evidence: The config line is explicit, and
`grep -n 'launchd\|system.defaults\|LoginItems' nix/flake.nix` returns nothing.
AeroSpace's own guide covers the Accessibility requirement; the repo does not.

Automated or manual: Undocumented manual work plus an unavoidable GUI approval

Current workaround: Launch AeroSpace by hand and approve it once.

Recommended change: Decide whether AeroSpace is meant to run. If yes, set
`start-at-login = true` and document the one-time Accessibility approval. If
the manual start is deliberate, say why in a comment, because the current file
reads like an oversight.

Verification: On a fresh account, complete the deployment and confirm whether
AeroSpace is running after a reboot without any manual step.

Confidence: verified

### A2-009

Finding ID: A2-009

Severity: medium

Platform and scenario: macOS with the source tree at a path containing spaces

Deployment phase: Every interactive shell after the first apply

Files and lines: `.chezmoitemplates/shell-interactive.sh:107`

Observed behavior: The alias renders the source path into a single-quoted alias
body without quoting the path itself:
`alias nix-switch='sudo darwin-rebuild switch --flake <path>/nix#macbook'`.
The alias expands at use time, so the shell word-splits the path.

Fresh-host consequence: `nix-switch` passes three arguments where one was
meant, and `darwin-rebuild` fails on a flake reference truncated at the first
space. The failure names a path fragment, not the real cause.

Reproduction or evidence: Rendering with
`--source "<scratch>/src with spaces"` produces the unquoted path. Running the
resulting alias against a `sudo` stub yields six arguments:
`[darwin-rebuild] [switch] [--flake] [/tmp/src] [with] [spaces/nix#macbook]`.
The Linux half of the same template does this correctly:
`.chezmoitemplates/shell-interactive.sh:114` uses
`printf "%s/dot_config/mise" .chezmoi.sourceDir | quote`. So does
`run_after_darwin-rebuild.sh.tmpl:12`, which quotes its assignment and every
use, and is safe.

Automated or manual: Automated

Current workaround: Keep the checkout at a path without spaces.

Recommended change: Render the path through `quote` inside a double-quoted
alias body, matching what the Linux branch and the drift hook already do.

Verification: Render from a source directory containing a space and confirm the
alias passes exactly one `--flake` argument.

Confidence: verified

### A2-010

Finding ID: A2-010

Severity: medium

Platform and scenario: macOS, every `darwin-rebuild switch` after the first

Deployment phase: Steady state

Files and lines: `nix/flake.nix:117`, `nix/flake.nix:143-147`

Observed behavior: `greedyCasks = true` marks every cask `greedy: true` in the
Brewfile, and `upgrade = true` omits `--no-upgrade`. Greedy means Homebrew
upgrades casks it would otherwise leave alone, including those that update
themselves. Most of this list does update itself: ChatGPT, Claude, Firefox,
Obsidian, Raycast, Spotify, Visual Studio Code, Zed and Rancher Desktop all
ship their own updaters.

Fresh-host consequence: Every activation re-downloads and replaces application
bundles that were already current, replacing a running app's bundle underneath
it. When a self-updater has moved ahead of the cask, the switch rolls the app
back to the cask's version, and the app updates itself again afterwards. The
result is a slow, noisy switch and applications that oscillate.

Reproduction or evidence: The evaluated Brewfile carries `greedy: true` on all
21 lines. nix-darwin's `homebrew.nix:195` is what omits `--no-upgrade` when
`upgrade = true`. Not executed here, since Homebrew is absent.

Automated or manual: Automated

Current workaround: Set `greedyCasks = false` and let each application update
itself.

Recommended change: Turn greedy off by default and enable it per cask for the
few that genuinely do not self-update. Greedy plus self-updating apps is the
combination Homebrew's own documentation warns about.

Verification: On a disposable Mac, activate twice with no changes and record
what Homebrew downloads on the second run. Compare against `greedyCasks = false`.

Confidence: likely

### A2-011

Finding ID: A2-011

Severity: medium

Platform and scenario: macOS, following the README's update instructions

Deployment phase: Steady state

Files and lines: `README.md:81-85`, `nix/flake.nix:61`

Observed behavior: The README documents `mise self-update` unconditionally.
On macOS the flake owns mise, so the binary is
`/nix/store/caclnwaxkz5c12y3yjzzjpfvndx9dvd9-mise-2026.8.3/bin/mise` behind a
symlink in the read-only store. The nixpkgs build does not disable the command:
`mise self-update --help` prints full usage, and mise itself reports that
2026.9.1 is available.

Fresh-host consequence: The documented command tries to overwrite a read-only
store path and fails. The correct action on macOS is
`nix flake update` followed by an activation, which the README does not say.

Reproduction or evidence: `type -a mise` resolves to
`/run/current-system/sw/bin/mise`, a symlink into the store.
`mise self-update --help` shows the command is present and offers `--force`.
This is the macOS counterpart of agent 4's finding, where Omarchy's `mise-bin`
package disables self-update outright and the command exits cleanly with an
explanation. On macOS there is no such guard, so the failure is uglier.

Automated or manual: Documentation error

Current workaround: Update mise by bumping the flake and activating.

Recommended change: Replace the single `mise self-update` block with the
per-platform owner: `nix flake update` plus activation on macOS, the Omarchy
package manager on Linux. Agent 4 asks for the same correction from the other
side.

Verification: Follow the README's update section on each platform and confirm
the documented command is the one that works.

Confidence: verified

### A2-012

Finding ID: A2-012

Severity: low

Platform and scenario: Apple Silicon macOS, first activation

Deployment phase: First nix-darwin activation

Files and lines: `nix/flake.nix:106`, `docs/package-lists/macos.md:10-13`

Observed behavior: A first activation builds 83 derivations locally and fetches
120 paths, 1218.75 MiB compressed and 4018.33 MiB unpacked. Terraform is built
from source rather than fetched, because the binary cache does not carry unfree
builds. Emacs, the Nerd Fonts and the Common Lisp closure that `mac-app-util`
pulls in make up most of the rest.

Fresh-host consequence: The first activation is a long, network-heavy step with
no time estimate anywhere in the docs. A user who assumes it is quick may
interrupt it.

Reproduction or evidence: `nix build --dry-run` with unfree allowed reports
both counts. Terraform appears in the build list, not the fetch list.

Automated or manual: Automated

Current workaround: None needed, but expectations should be set.

Recommended change: Note the rough download size and the fact that the first
activation compiles, in the macOS cold-start procedure. Dropping `terraform`
per A2-002 also removes the only from-source build of consequence.

Verification: Time a first activation on a disposable host and record the
figure.

Confidence: verified

### A2-013

Finding ID: A2-013

Severity: low

Platform and scenario: macOS with AeroSpace

Deployment phase: Configuration load

Files and lines: `dot_config/aerospace/aerospace.toml:4`

Observed behavior: `after-login-command` has been deprecated since AeroSpace
0.19.0. The current parser routes it to `parseDeprecatedAfterLoginCommand`,
which returns success only for an empty array and otherwise fails the config
with a deprecation message. The repo sets `[]`, so it parses today and does
nothing.

Fresh-host consequence: None now. Giving the key a value later breaks config
loading with a message about a key the author thought was supported.

Reproduction or evidence: `parseConfig.swift:131` maps the key to the
deprecated parser, and lines 176-182 show the empty-array success path and the
failure message. The rendered config parses as valid TOML with the expected 34
main and 11 service bindings. `config-version = 2` is current and correct.

Automated or manual: Automated

Current workaround: None needed.

Recommended change: Delete the line.

Verification: Confirm AeroSpace loads the config without diagnostics after
removal.

Confidence: verified

### A2-014

Finding ID: A2-014

Severity: low

Platform and scenario: macOS, any host not named `macbook`

Deployment phase: Activation

Files and lines: `nix/flake.nix:163-170`, `docs/package-lists/macos.md:11-17`

Observed behavior: The only `darwinConfigurations` entry is `macbook`. This
host is `lagrange`. Every documented command names `#macbook` explicitly, so
they work, but `darwin-rebuild switch --flake <path>` without the fragment
looks for `darwinConfigurations.lagrange` and fails.

Fresh-host consequence: Minor. It costs a confusing error the first time
someone shortens the command, and it means a second Mac cannot be added without
either sharing the `macbook` name or restructuring the outputs.

Reproduction or evidence: `hostname` returns `lagrange`. The flake defines one
configuration. `docs/package-lists/macos.md:16-17` already states that
`darwinConfigurations` defines only `macbook`, for `aarch64-darwin`.

Automated or manual: Automated

Current workaround: Always pass `#macbook`.

Recommended change: Either name the configuration after the host and generate
the set from a small host list, which also gives A2-001 somewhere natural to
live, or add an alias so the bare form resolves. The current state is fine for
exactly one Mac and awkward for two.

Verification: Add a second host to the set and confirm both activate with the
bare and explicit forms.

Confidence: verified

## Confirmations of other agents' findings on macOS

- A1-003, the drift hook with no current generation, reproduces on real macOS.
  Pointing the hook at an empty fixture root makes `sed` fail to open the
  activation script; under `pipefail` the hook exits 1 and the apply stops.
  Agent 1 recorded exit 2 from a stub environment. The fix they propose is
  right, and A2-003 is a separate problem in the same script.
- A1-007, the macOS-only hook running on Linux, is consistent with what macOS
  sees. `chezmoi managed --include=scripts` here lists four scripts:
  `darwin-rebuild.sh`, `install-doom-emacs.sh`, `mise-install.sh` and
  `trust-local-projects-mise.sh`. The Omarchy and Linux drift hooks are
  correctly excluded.
- A1-002, the missing cold-start documentation, is worse on macOS than agent 1
  could establish from Linux. The bootstrap table above adds Xcode Command Line
  Tools, Determinate Nix, Homebrew, the mandatory `username` edit, and the
  Accessibility approval, none of which appear in the repo.
- A4's `mise self-update` finding has a distinct macOS failure mode. See
  A2-011.

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
git diff --stat 30923db..abb2e56

id -un; hostname; sw_vers; uname -a
xcode-select -p; pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
ls /opt/homebrew /usr/local/Homebrew          (absent)
ls -l /run/current-system and each compared symlink
grep -B3 -A12 'primaryUser=' /run/current-system/activate

nix flake metadata --no-write-lock-file nix
nix flake check --no-write-lock-file nix
nix build --dry-run --no-link --no-write-lock-file '#darwinConfigurations.macbook.system'
  (same, with NIXPKGS_ALLOW_UNFREE=1 --impure)
nix eval  system.primaryUser, homebrew.casks, homebrew.brewfile,
          fonts.packages, system.activationScripts.script.text,
          system.activationScripts.homebrew.text
per-package sweep of meta.unfree, meta.broken and meta.platforms for all 62
  environment.systemPackages entries on aarch64-darwin

chezmoi doctor
chezmoi managed --include=files, --include=scripts
chezmoi apply --dry-run --force --verbose --refresh-externals=never
  into an isolated destination and persistent state
chezmoi execute-template --file  for the drift hook, ghostty config,
  shell-interactive.sh and dot_zshrc.tmpl, including a source tree whose
  path contains spaces

bash -n on the rendered drift hook
live run of the rendered drift hook
same hook rerun with unfree allowed, to prove the comparison logic
same hook against an empty fixture root, to reproduce the missing generation
alias word-splitting test against a sudo stub under zsh

ghostty +validate-config on the rendered macOS config (Ghostty 1.3.1)
ghostty +validate-config on a deliberately invalid file, as a harness check
python3 tomllib parse of dot_config/aerospace/aerospace.toml

Homebrew API cask JSON for all 21 casks: availability, version, artifacts,
  depends_on macos, depends_on arch, variations
nikitabobko/homebrew-tap Casks/aerospace.rb
AeroSpace default-config.toml, guide, commands index, and
  Sources/AppBundle/config/parseConfig.swift
Homebrew Library/Homebrew/cask/artifact/moved.rb
nix-darwin modules/homebrew.nix
```

Not run on this host: `darwin-rebuild switch`, the Homebrew installer, any
cask installation, and any Accessibility or login-item approval. Those need the
disposable Apple Silicon stage, and several of the findings above are the
reason that stage cannot start yet.
