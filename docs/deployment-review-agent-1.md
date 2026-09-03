# Agent 1 deployment review: chezmoi bootstrap and lifecycle

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-02

Local review host: Omarchy 4.0.2, Linux amd64, chezmoi 2.72.0

## Workstream verdict

The lifecycle workstream is blocked. `.chezmoiremove` is an active deletion
policy with 45 entries, including whole directories. Most entries describe old
migrations, but chezmoi applies them forever. A disposable-home test confirmed
that an unrelated file below `~/.config/themes` is deleted recursively.

The regular target set converged in a disposable home. Both the current
Omarchy render and a simulated Apple Silicon macOS render had empty
`chezmoi status` output after the first files-only apply and after a second
apply. This does not replace either platform cold-start test. Scripts that
install packages, activate nix-darwin, or change the live Omarchy session were
not run on a disposable host.

There are six more findings. Three can interrupt or prevent first-time setup,
and three document lifecycle behavior that the current README does not make
clear.

## Target-selection matrix

Architecture does not affect target selection. The only selection inputs are
`.chezmoi.os` and the four Omarchy signals in
`.chezmoitemplates/omarchy-detect.tmpl`. Hostname changes the contents of
`~/.config/hypr/monitors.lua`, not whether chezmoi manages the file.

| Scenario | Omarchy result | Platform-managed additions | Platform ignores | After scripts, in order |
| --- | --- | --- | --- | --- |
| Apple Silicon macOS | false | `~/.config/aerospace/aerospace.toml` | Hypr, superfile, Omarchy package hook, Linux drift hook | darwin drift, Doom, mise install, mise trust |
| Omarchy 4 | true through `ID=omarchy` or `/usr/share/omarchy` | four Hypr files and superfile | AeroSpace | darwin no-op, Doom, Omarchy packages, Linux drift, mise install, mise trust |
| Legacy Omarchy 3 | true through `~/.local/share/omarchy` | same as Omarchy 4 | AeroSpace | same as Omarchy 4 |
| Valid dev-linked Omarchy | true when `OMARCHY_PATH` exists | same as Omarchy 4 | AeroSpace | same as Omarchy 4 |
| Generic Linux | false | superfile | AeroSpace, Hypr, Omarchy package hook | darwin no-op, Doom, Linux drift, mise install, mise trust |
| Unknown Omarchy hostname | true through any Omarchy signal | same as Omarchy 4; monitor file uses the default output and automatic scale | AeroSpace | same as Omarchy 4 |

A stale `OMARCHY_PATH` counts as Omarchy whenever the path still exists. The
detection template checks existence, not that the path is a valid Omarchy
tree. Agent 3 owns the deeper detection review.

## Path inventory

### Managed files common to every scenario

Chezmoi manages these 62 repo-owned files on every scenario in the matrix.
Parent directories are implicit.

```text
~/.bash_profile
~/.bashrc
~/.cargo/config.toml
~/.claude/hooks/block-git-rewrites.py
~/.claude/settings.json
~/.claude/skills/omarchy/SKILL.md
~/.condarc
~/.config/atuin/config.toml
~/.config/atuin/themes/gruvbox-dark.toml
~/.config/bat/config
~/.config/btop/btop.conf
~/.config/btop/themes/gruvbox_dark_v2.theme
~/.config/dask/distributed.yaml
~/.config/doom/config.el
~/.config/doom/init.el
~/.config/doom/packages.el
~/.config/doom/snippets/README.md
~/.config/ghostty/config
~/.config/git/config
~/.config/git/ignore
~/.config/herdr/config.toml
~/.config/lazygit/config.yml
~/.config/mise/conf.d/10-dotfiles.toml
~/.config/nvim/.neoconf.json
~/.config/nvim/LICENSE
~/.config/nvim/README.md
~/.config/nvim/after/plugin/transparency.lua
~/.config/nvim/init.lua
~/.config/nvim/lazyvim.json
~/.config/nvim/lua/config/autocmds.lua
~/.config/nvim/lua/config/keymaps.lua
~/.config/nvim/lua/config/lazy.lua
~/.config/nvim/lua/config/options.lua
~/.config/nvim/lua/plugins/disable-news-alert.lua
~/.config/nvim/lua/plugins/snacks-animated-scrolling-off.lua
~/.config/nvim/lua/plugins/theme.lua
~/.config/nvim/stylua.toml
~/.config/opencode/opencode.json
~/.config/opencode/plugins/block-git-rewrites.ts
~/.config/starship.toml
~/.config/tmux/tmux.conf
~/.config/zed/settings.json
~/.config/zellij/config.kdl
~/.direnvrc
~/.gemini/GEMINI.md
~/.gemini/hooks/block-git-rewrites.py
~/.gemini/settings.json
~/.inputrc
~/.local/bin/install-micromamba-env
~/.local/bin/jupyter-remote-lab
~/.local/bin/uninstall-micromamba-env
~/.mambarc
~/.npmrc
~/.profile
~/.vim/plugin/keymaps.vim
~/.vimrc
~/.zprofile
~/.zshenv
~/.zshrc
~/local-codex/environments/analysis_environment.yml
~/local-codex/environments/jupyter_environment.yml
~/local-projects/.mise.toml
```

Tracked `.gitkeep` files cause chezmoi to create these otherwise empty
directories:

```text
~/.local/opt
~/.vim/undo-dir
~/local-codex
~/local-codex/screenshots
~/local-journal
~/local-journal/org
~/local-projects
~/local-projects/codes
~/local-projects/tries
```

Two empty directories present in this checkout,
`dot_config/bat/themes` and `dot_config/zellij/themes`, are not tracked. A new
clone will not contain or apply them.

### Conditional managed files

macOS adds:

```text
~/.config/aerospace/aerospace.toml
```

All Linux scenarios add:

```text
~/.config/superfile/config.toml
```

Detected Omarchy scenarios also add:

```text
~/.config/hypr/bindings.lua
~/.config/hypr/hyprland.lua
~/.config/hypr/looknfeel.lua
~/.config/hypr/monitors.lua
```

### Ignored paths

These source-tree paths are always ignored and never applied to `$HOME`:

```text
AGENTS.md
CLAUDE.md
LICENSE
README.md
.mailmap
.codex
.gitignore
docs/**
scripts/**
nix/**
dot_config/mise/mise.lock
```

The ignore template names `.mailmap` and the repo content directly. Chezmoi's
source-name rules also omit the tracked `.codex` and `.gitignore` files.

Chezmoi also consumes `.chezmoi.toml.tmpl`, `.chezmoiignore.tmpl`,
`.chezmoiremove`, `.chezmoidata/**`, `.chezmoitemplates/**`, and each
`.chezmoiexternal.toml.tmpl` as control input rather than home-directory
targets.

Conditional ignores are:

```text
non-macOS:       .config/aerospace/**
non-Linux:       linux-package-drift.sh, .config/superfile/**
non-Omarchy:     install-omarchy-packages.sh, .config/hypr/**
```

### Removed paths

Every entry below is an active rule on every apply. These are not conditioned
by operating system or by evidence that chezmoi created the existing path.

```text
~/.config/lazygit/config.yaml
~/.config/omarchy/extensions/menu.sh
~/.config/mise/config.toml
~/.local/bin/claude
~/.local/bin/codex
~/.local/bin/gemini
~/.local/bin/gh
~/.local/bin/opencode
~/.local/bin/pi
~/.bash-preexec.sh
~/.aerospace.toml
~/.gitconfig
~/.hyprspace.toml
~/.icas.toml
~/.Brewfile
~/.local/bin/check-homebrew
~/.local/bin/dump-homebrew
~/.local/bin/sync-homebrew
~/.local/bin/sync-uv
~/.local/bin/sync-bun
~/.config/shell/00_init.sh
~/.config/shell/05_prefer_zsh.sh
~/.config/shell/05_zsh_completions.sh
~/.config/shell/10_bash_init.sh
~/.config/shell/15_host_env.sh
~/.config/shell/25_nvim.sh
~/.config/shell/30_env.sh
~/.config/shell/30_interactive.sh
~/.config/shell/35_keychain.sh
~/.config/shell/40_python.sh
~/.config/shell/45_omarchy.sh
~/.config/shell/99_finish.sh
~/.config/shell/base.sh
~/.config/shell/interactive.sh
~/.config/shell/lib.sh
~/.config/shell/personal
~/.config/shell/work
~/.config/themes
~/.config/btop/themes/current.theme
~/.config/omarchy/hooks/theme-set
~/.config/atuin/themes/rose-pine-moon.toml
~/.config/bat/themes/rose-pine-moon.tmTheme
~/.config/btop/themes/rose-pine-moon.theme
~/.config/zellij/themes/rose-pine-moon.kdl
~/.vim/pack/plugins/start/rose-pine
```

### Externally fetched paths

The single external declaration manages six exact archive roots. URLs point at
Git commit archives, but no content checksums are declared.

```text
~/.vim/pack/plugins/start/gruvbox
~/.vim/pack/plugins/start/nerdcommenter
~/.vim/pack/plugins/start/nerdtree
~/.vim/pack/plugins/start/vim-airline
~/.vim/pack/plugins/start/vim-fugitive
~/.vim/pack/plugins/start/vim-surround
```

Each external has `exact = true`, so chezmoi removes files below its plugin
root when they are absent from the selected archive contents.

### Script-generated state

The scripts do not remain as files in `$HOME`. They run from temporary rendered
content and create or modify this state:

| Script | Generated or modified state |
| --- | --- |
| `install-doom-emacs.sh` | Git checkout at `~/.config/emacs`, detached at the revision in `.chezmoidata/versions.yaml`; Doom package and generated state produced by `doom install` |
| `install-omarchy-packages.sh` | 46 pacman packages and 2 AUR packages through `omarchy pkg`; package-manager databases and package files |
| `mise-install.sh` | mise installs, shims, caches, and metadata, normally below `~/.local/share/mise`, using the repo lock on Linux |
| `trust-local-projects-mise.sh` | trust record below `~/.local/state/mise/trusted-configs` for `~/local-projects/.mise.toml` |
| `darwin-rebuild.sh` | no state; evaluates and reports drift |
| `linux-package-drift.sh` | no state; reports duplicate user-installed commands |

Chezmoi also records successful `run_onchange` content hashes in its persistent
state database.

## Render and execution order

Chezmoi applies normal files, directories, removals, and external contents
before any `run_after` script. It then sorts the scripts by destination name,
after removing source attributes such as `run_onchange_after_`.

The resulting order on detected Omarchy is:

1. `darwin-rebuild.sh`, every apply, normally exits because the command is absent.
2. `install-doom-emacs.sh`, when its rendered content hash is new.
3. `install-omarchy-packages.sh`, every apply.
4. `linux-package-drift.sh`, every apply.
5. `mise-install.sh`, when its rendered content hash is new.
6. `trust-local-projects-mise.sh`, when its rendered content hash is new.

Chezmoi renders after scripts lazily. A disposable fixture installed a command
in script 10. Templates for scripts 20 and 30 saw its path and their runtime
checks invoked it during the same apply. A second fixture put the consumer
before the installer. The consumer exited successfully and chezmoi recorded
that hash. On the next apply, its embedded `lookPath` changed, so chezmoi ran it
again. A third apply did not rerun it.

This gives the current hooks the following retry rules:

| Missing dependency | First apply | How it becomes eligible again |
| --- | --- | --- |
| Git or Emacs | Doom exits 0. On Omarchy, Doom precedes the package hook, so a newly installed Emacs is too late. | The embedded `lookPath` changes on the next apply. |
| mise | mise install and mise trust exit 0. No hook installs the mise executable. | Install mise manually or through nix-darwin, then apply again. Both embedded paths change. |
| bun or uv on Omarchy | The package hook installs them before mise runs. | They are usable by mise in the same apply. |
| bun or uv on macOS or generic Linux | mise exits nonzero. | Install both, then rerun apply. A failed `run_onchange` remains pending. |
| Nix | The darwin drift hook exits if `darwin-rebuild` is absent. | It is an every-apply hook, so the next apply retries it. |
| nix-darwin | Same as Nix. | Activate nix-darwin separately, then apply again. |

## Expected apply timelines

### Apple Silicon macOS

1. Manually install enough bootstrap tooling to obtain the repo and run
   chezmoi. The repo does not automate or document this stage.
2. The first apply writes normal targets and fetches the six Vim externals.
   Doom, mise installation, and mise trust skip if nix-darwin has not supplied
   their commands yet.
3. Manually install Nix and perform the first nix-darwin activation. This is
   intentionally outside `chezmoi apply`.
4. Run a second apply. The new Emacs and mise paths change both `run_onchange`
   hashes. Doom installs and mise installs the shared tools.
5. Log in again where required for the new system and shell configuration.
6. A final apply should have no file changes. The darwin drift check still
   evaluates on every apply.

### Omarchy

1. Manually obtain the repo and initialize chezmoi. A stock Omarchy image is
   expected to supply chezmoi and mise, but this assumption is not documented
   as a prerequisite.
2. The first apply writes normal targets and fetches externals. Doom skips when
   Emacs is absent. The Omarchy hook then restores 46 pacman and 2 AUR packages,
   including Emacs, bun, and uv. Mise can use bun and uv later in the same
   apply, then the trust hook runs.
3. Run a second apply. Doom now sees Emacs and installs its checkout and
   packages.
4. Log in again or restart the session for shell and desktop changes.
5. A final apply should have no file changes. It is not command-free. The
   Omarchy package hook still calls both package helpers, and both reporting
   hooks still run.

## External and convergence tests

| Case | Result |
| --- | --- |
| Empty cache, `--refresh-externals=never` | Exit 1. Chezmoi attempted the first GitHub download because no cached body existed. |
| Populated cache, `--refresh-externals=never`, network forced unavailable | Exit 0. All six archives came from cache. |
| Empty cache, network forced unavailable | Exit 1 before writing any destination file. |
| Current Omarchy render, files and externals only | 209 destination files; empty status after first and second apply. |
| Simulated `darwin/arm64` render, files and externals only | All templates rendered; AeroSpace present; Hypr and superfile absent; empty status after apply. |
| Rendered shell syntax | `bash -n` passed for every Omarchy script and every macOS-selected script. |

`--refresh-externals=never` prevents refresh of a populated cache. It does not
make a cold cache offline-capable.

## Findings

### A1-001

Finding ID: A1-001

Severity: blocker

Platform and scenario: All platforms, any apply after a user or application
recreates a retired path

Deployment phase: Every apply, removal phase

Files and lines: `.chezmoiremove:1-83`

Observed behavior: Chezmoi treats all 45 entries as permanent removal rules.
Many comments call them one-time migration cleanup. Directory targets are
removed recursively without checking their contents or provenance.

Fresh-host consequence: A fresh host can already contain legitimate data at a
generic path such as `~/.gitconfig`, `~/.Brewfile`, or `~/.config/themes`.
Chezmoi deletes it. The same loss can happen years later if another tool starts
using one of these paths.

Reproduction or evidence: In a disposable destination, I created
`~/.gitconfig` and `~/.config/themes/sub/keep`, then applied only the `remove`
entry type. Chezmoi deleted the file and the whole populated directory while
leaving an unrelated control file intact.

Automated or manual: Automated and unconditional

Current workaround: Review `.chezmoiremove` before every first apply and use a
separate backup or exclude the `remove` entry type.

Recommended change: Remove expired migration entries. Where an invariant is
still required, replace the unconditional rule with a guarded migration that
checks the expected old content or ownership before deletion. Do not use a
bare `run_once` deletion on a fresh host without those guards.

Verification: Seed every old path with both the known retired content and an
unknown sentinel. Confirm the migration removes only the known content and
preserves the sentinel. Repeat apply and confirm no deletion rule remains.

Confidence: verified

### A1-002

Finding ID: A1-002

Severity: high

Platform and scenario: Apple Silicon macOS and a fresh Omarchy account

Deployment phase: Bootstrap through second apply

Files and lines: `README.md:13-24`, `README.md:26-41`

Observed behavior: The README starts with `chezmoi apply`. It does not explain
how to install chezmoi, obtain or initialize this source tree, install Nix,
perform the first nix-darwin activation, verify Omarchy prerequisites, or run
the required second apply after package installation.

Fresh-host consequence: A stock macOS host cannot execute the first documented
command. On both platforms, a user can stop after a successful first apply
with Doom and mise setup skipped.

Reproduction or evidence: The bootstrap and dependency timeline above follows
the executable guards in all six hooks. The README has no `chezmoi init`, clone,
Nix installation, first activation, reboot or login, or second-apply sequence.

Automated or manual: Missing manual procedure

Current workaround: Know the bootstrap sequence outside the repo, install the
platform prerequisites, and apply again after they appear on `PATH`.

Recommended change: Add one cold-start procedure per supported platform. Name
manual prerequisites, source initialization, network requirements, first
apply, nix-darwin or package activation, login or reboot, second apply, and the
final status check.

Verification: Follow each document on a stock disposable host without relying
on prior knowledge or copied caches.

Confidence: verified

### A1-003

Finding ID: A1-003

Severity: high

Platform and scenario: macOS with `darwin-rebuild` on `PATH` but no active
`/run/current-system`

Deployment phase: Transition before the first nix-darwin generation

Files and lines: `run_after_darwin-rebuild.sh.tmpl:10-14`,
`run_after_darwin-rebuild.sh.tmpl:34-49`

Observed behavior: The script guards only the presence of `darwin-rebuild`.
It then reads `/run/current-system/activate` under `set -euo pipefail` without
checking that the first generation exists.

Fresh-host consequence: Chezmoi exits during its after-script phase instead of
reporting that nix-darwin still needs its first activation.

Reproduction or evidence: I rendered the macOS branch, supplied stub
`darwin-rebuild` and `nix eval` commands, and left `/run/current-system`
absent. `sed` failed to open the activation script and the hook exited 2.

Automated or manual: Automated failure in a manual activation transition

Current workaround: Complete the first nix-darwin activation before applying,
or exclude scripts until `/run/current-system/activate` exists.

Recommended change: Guard `/run/current-system/activate` and the expected links.
When absent, print the exact first-activation command and exit 0.

Verification: Test with no current generation, a matching generation, a
drifted generation, and a failed flake evaluation on an Apple Silicon macOS
snapshot.

Confidence: verified

### A1-004

Finding ID: A1-004

Severity: high

Platform and scenario: Omarchy, one optional AUR package unavailable or failing
to build

Deployment phase: First apply, package installation before mise and trust

Files and lines: `run_after_install-omarchy-packages.sh.tmpl:9-30`,
`run_onchange_after_mise-install.sh.tmpl:15-46`

Observed behavior: One every-apply hook installs all pacman packages and then
both AUR packages under `set -e`. An AUR failure returns nonzero. Because mise
and trust sort later, ordinary apply stops before either hook runs.

Fresh-host consequence: A failure in Slack or Google Cloud CLI can prevent the
shared runtime and CLI installation from starting, even after all pacman
packages were installed successfully.

Reproduction or evidence: A stub `omarchy` command accepted the pacman call and
returned 42 for `pkg aur add`. The rendered hook exited 42 after exactly those
two calls. The script-only dry run confirmed that mise and trust sort later.

Automated or manual: Automated

Current workaround: Repair or remove the failing AUR package, then rerun apply.
`--keep-going` may reduce the interruption but is not the documented workflow.

Recommended change: Separate required system packages, optional AUR packages,
and runtime setup into hooks whose failure boundaries match their importance.
Do not let an optional GUI package prevent mise from running.

Verification: Force each package group to fail independently and confirm that
required later setup still runs while the apply reports the failed group.

Confidence: verified

### A1-005

Finding ID: A1-005

Severity: medium

Platform and scenario: Generic Linux or an Omarchy installation that does not
already include mise

Deployment phase: First apply, runtime installation

Files and lines: `.chezmoidata/packages.yaml:3-53`,
`run_onchange_after_mise-install.sh.tmpl:12-20`,
`run_onchange_after_trust-local-projects-mise.sh.tmpl:6-11`, `README.md:43-85`

Observed behavior: Neither the package list nor another hook installs the mise
executable. Both mise hooks exit 0 when it is absent. Their rendered
`lookPath` values make them retry after mise appears, but the repo does not say
how it should appear on Linux.

Fresh-host consequence: The apply reports success without installing any of
the declared runtimes or global CLI tools. Generic Linux also fails later if
mise exists but bun or uv does not.

Reproduction or evidence: Rendering with an empty `PATH` produced
`# mise executable: ""` in both hooks. Each runtime guard exits 0. The Omarchy
package data contains 46 pacman entries and 2 AUR entries, none named `mise`.

Automated or manual: Undocumented manual prerequisite

Current workaround: Install mise through the host package manager, then apply
again. On generic Linux, install bun and uv before that retry as well.

Recommended change: Declare the supported Linux bootstrap owner for mise and
document it. If generic Linux is unsupported, say so and remove it from the
deployment matrix. If it is supported, add a safe bootstrap path for mise, bun,
and uv.

Verification: Start with all three commands absent, follow only the documented
procedure, and confirm the second apply installs the locked tool set.

Confidence: verified

### A1-006

Finding ID: A1-006

Severity: low

Platform and scenario: Any fresh host with an empty chezmoi external cache and
no network

Deployment phase: Target-state construction before files or scripts

Files and lines: `README.md:19-20`,
`dot_vim/pack/plugins/start/.chezmoiexternal.toml.tmpl:1-53`

Observed behavior: `--refresh-externals=never` still fetches an external when
the cache has no body. With a cold cache and no network, apply fails before
writing any normal destination file.

Fresh-host consequence: Neither a dry run nor the first apply can run offline,
even with the README's no-refresh command.

Reproduction or evidence: An empty cache plus a blocked proxy caused chezmoi to
attempt the first GitHub archive and exit 1. The disposable destination still
contained zero files. Repeating with the populated local cache exited 0 while
the same proxy block was active.

Automated or manual: Manual network prerequisite

Current workaround: Run once with network access or copy a populated chezmoi
cache from a trusted machine.

Recommended change: Document that `never` means no refresh, not no initial
download. If offline cold starts matter, vendor the small pinned Vim plugins or
provide a verified cache-seeding procedure.

Verification: Repeat the empty-cache and populated-cache tests with network
access disabled at the host boundary.

Confidence: verified

### A1-007

Finding ID: A1-007

Severity: low

Platform and scenario: Every Linux host

Deployment phase: Every apply, first after script

Files and lines: `.chezmoiignore.tmpl:21-33`,
`run_after_darwin-rebuild.sh.tmpl:1-14`

Observed behavior: The ignore template excludes AeroSpace outside macOS and
Linux drift outside Linux, but it never excludes `darwin-rebuild.sh` outside
macOS. Every Linux apply renders and runs the macOS-only hook. It normally exits
at its command guard.

Fresh-host consequence: There is needless script execution and persistent
state noise. A Linux host with an unrelated `darwin-rebuild` command could
continue into macOS-specific `/run/current-system` checks.

Reproduction or evidence: `chezmoi managed --include=scripts` on Omarchy listed
`darwin-rebuild.sh`, and the script-only dry run placed it first.

Automated or manual: Automated

Current workaround: None needed on ordinary Linux because the command guard
returns 0.

Recommended change: Add `darwin-rebuild.sh` to the non-macOS ignore branch.

Verification: Confirm the managed script lists contain four scripts on macOS,
four on generic Linux, and five on Omarchy after removal of the cross-platform
no-op.

Confidence: verified

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
chezmoi execute-template --file <every template>
chezmoi apply --dry-run --verbose --include=scripts
chezmoi apply --exclude=scripts into disposable destinations
chezmoi status after first and second disposable applies
bash -n on every selected rendered script
empty and populated external-cache tests with network forced unavailable
disposable lifecycle fixtures for lazy rendering and run_onchange retry
disposable removal fixture with populated migration paths
stubbed darwin transition and Omarchy AUR failure tests
```

The review did not run `darwin-rebuild switch`, `omarchy pkg`, desktop reloads,
or package installation against the live host. Those checks belong in the
disposable platform stage.
