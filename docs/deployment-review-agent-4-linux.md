# Agent 4 deployment review: Linux package and runtime ownership

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-02

Local review host: Omarchy 4.0.2-1, Linux x86_64, mise 2026.8.15,
chezmoi 2.72.0

## Scope

This is the Linux and Omarchy half of Agent 4's package and runtime ownership
workstream. I reviewed:

- `.chezmoidata/packages.yaml`
- `run_after_install-omarchy-packages.sh.tmpl`
- `dot_config/mise/conf.d/10-dotfiles.toml`
- `dot_config/mise/mise.lock`
- the Linux `mup` function and mise install hook
- Doom's pinned checkout and the six Vim externals
- current Omarchy 4.0.2 package defaults under `/usr/share/omarchy/`
- the live pacman database and package history

I did not review `nix/flake.nix`, Homebrew, macOS package resolution, Apple
Silicon, or Intel macOS. A macOS reviewer must complete those parts of Agent
4's assignment.

## Workstream verdict

The package workstream is not ready for an unattended fresh Omarchy apply.
Stock Omarchy installs `tldr`, but this repo requests `tealdeer`, which conflicts
with it. Pacman cannot complete the first package transaction until the user
removes `tldr` manually. That recovery is neither automated nor documented.

Three lower-severity Agent 4 findings remain after that failure:

- mise shadows Omarchy-owned `herdr`, `usage`, and `tree-sitter` commands.
- The documented `mise self-update` command cannot update Omarchy's
  package-managed mise binary.
- The Linux lock and update command support x86_64 only, but the documentation
  never states that boundary.

Agent 3 independently verified that every detected Omarchy host gets the
NVIDIA CUDA build of Ollama and more than 5.6 GiB of CUDA files, regardless of
its GPU. The package matrix below retains the ownership evidence, but A3-004 is
the single formal finding for that cause.

The current x86_64 mise lock is otherwise internally consistent. All 28
declarations have lock entries with matching versions, backends, and options.
All 11 lockable binary-artifact entries have a `linux-x64` URL and checksum.
`mise install --dry-run --locked` passed on the review host.

## Linux ownership matrix

### Pacman and AUR declarations

The Omarchy manifest contains 46 pacman entries and two AUR entries. The live
Omarchy 4.0.2 databases resolved every pacman entry: 42 from Arch `extra`, one
from Arch `core`, and three from the Omarchy repository. Both AUR entries were
available and not flagged out of date when queried on 2026-09-02.

Nine manifest entries are already part of the stock Omarchy package list:
`bat`, `btop`, `eza`, `fd`, `fzf`, `lazygit`, `ripgrep`, `starship`, and
`zoxide`. This is not duplicate ownership. Pacman remains their single owner,
and the manifest makes their presence an explicit invariant.

| Declaration | Owner and source | Installed command or application | Extra state or requirement |
| --- | --- | --- | --- |
| `aspell` | pacman, `extra` | `aspell` and helpers | Dictionary engine |
| `aspell-en` | pacman, `extra` | no command | English dictionaries for aspell |
| `ast-grep` | pacman, `extra` | `ast-grep` | None |
| `atuin` | pacman, `extra` | `atuin` | Account sync is optional and manual |
| `bat` | pacman, `extra`, stock Omarchy | `bat` | None |
| `bitwarden` | pacman, `extra` | `bitwarden-desktop` | Login is manual |
| `bitwarden-cli` | pacman, `extra` | `bw` | Login or unlock is manual |
| `btop` | pacman, `extra`, stock Omarchy | `btop` | None |
| `bun` | pacman, `extra` | `bun`, `bunx` | Backend for mise npm installs |
| `chezmoi` | pacman, `extra` | `chezmoi` | Bootstrap and future applies |
| `cmake` | pacman, `extra` | `cmake`, `ctest`, `cpack`, `ccmake` | Build toolchain |
| `direnv` | pacman, `extra` | `direnv` | Shell integration is repo-managed |
| `dropbox` | pacman, Omarchy repo | `dropbox` | Login and desktop startup are manual |
| `dropbox-cli` | pacman, Omarchy repo | `dropbox-cli` | Uses the Dropbox daemon |
| `duf` | pacman, `extra` | `duf` | None |
| `dust` | pacman, `extra` | `dust` | None |
| `emacs-wayland` | pacman, `extra` | `emacs`, `emacsclient` | Enables the later Doom hook |
| `eza` | pacman, `extra`, stock Omarchy | `eza`, `exa` | None |
| `fd` | pacman, `extra`, stock Omarchy | `fd` | None |
| `firefox` | pacman, `extra` | `firefox` | Browser sign-in is manual |
| `fzf` | pacman, `extra`, stock Omarchy | `fzf`, `fzf-tmux` | None |
| `ghostty` | pacman, `extra` | `ghostty` | None |
| `git-delta` | pacman, `extra` | `delta` | Used by Git configuration |
| `graphviz` | pacman, `extra` | `dot` and Graphviz tools | None |
| `hyperfine` | pacman, `extra` | `hyperfine` | None |
| `keychain` | pacman, `extra` | `keychain` | SSH key material remains manual |
| `lazygit` | pacman, `extra`, stock Omarchy | `lazygit` | None |
| `lua-language-server` | pacman, `extra` | `lua-language-server` | None |
| `neovim` | pacman, `extra` | `nvim` | Also a dependency of stock `omarchy-nvim` |
| `ollama-cuda` | pacman, `extra` | no command itself; depends on `ollama` | NVIDIA CUDA, system service, models are manual |
| `pinentry` | pacman, `core` | `pinentry` variants | GPG key import remains manual |
| `pixi` | pacman, `extra` | `pixi` | None |
| `ripgrep` | pacman, `extra`, stock Omarchy | `rg` | Used by Vim and shell helpers |
| `sccache` | pacman, `extra` | `sccache` | Remote cache setup is manual if wanted |
| `shellcheck` | pacman, `extra` | `shellcheck` | None |
| `starship` | pacman, `extra`, stock Omarchy | `starship` | Shell integration is repo-managed |
| `superfile` | pacman, `extra` | `spf` | None |
| `tailscale` | pacman, `extra` | `tailscale`, `tailscaled` | Enablement and `tailscale up` are manual |
| `tealdeer` | pacman, `extra` | `tldr` | Conflicts with stock Omarchy's `tldr` package |
| `uv` | pacman, `extra` | `uv`, `uvx` | Backend for mise pipx installs |
| `vim` | pacman, `extra` | `vim`, `vimdiff`, `vimtutor` | Plugins come from chezmoi externals |
| `visual-studio-code-bin` | pacman, Omarchy repo | `code` | Application onboarding is manual |
| `zed` | pacman, `extra` | `zeditor` | Pulls system Node and npm; onboarding is manual |
| `zellij` | pacman, `extra` | `zellij` | None |
| `zoxide` | pacman, `extra`, stock Omarchy | `zoxide` | Shell integration is repo-managed |
| `zsh` | pacman, `extra` | `zsh` | Required for the repo's preferred shell handoff |
| `google-cloud-cli` | AUR | `gcloud` and credential helpers | `gcloud auth login` is manual |
| `slack-desktop` | AUR | `slack` | Login is manual |

The AUR sources were checked against the current
[`google-cloud-cli`](https://aur.archlinux.org/packages/google-cloud-cli) and
[`slack-desktop`](https://aur.archlinux.org/packages/slack-desktop) package
records. Their availability does not make a cold apply offline-capable. AUR
build metadata and upstream application archives still require the network.

### mise declarations and lock entries

The table lists the requested selector, the reviewed Linux lock resolution,
the backend, and the primary installed command. `latest` is not resolved at
shell startup. The committed lock supplies the concrete version until `mup`
updates it.

| Tool declaration | Locked version | Backend | Primary command |
| --- | --- | --- | --- |
| `node = 26.8.0` | 26.8.0 | `core:node` | `node`, `npm`, `npx` |
| `python = 3.14.7` | 3.14.7 | `core:python` | `python`, `python3`, `pip` |
| `go = 1.27.0` | 1.27.0 | `core:go` | `go`, `gofmt` |
| `rust = stable` | `stable` | `core:rust` | `rustc`, `cargo`, rustup proxies |
| `claude = latest` | 2.1.258 | `aqua:anthropics/claude-code` | `claude` |
| `codex = latest` | 0.152.1 | `aqua:openai/codex` | `codex` |
| `opencode = latest` | 1.18.26 | `aqua:anomalyco/opencode` | `opencode` |
| `pi = latest` | 0.84.4 | `aqua:earendil-works/pi` | `pi` |
| `npm:@google/gemini-cli = latest` | 0.58.0 | npm | `gemini` |
| `npm:@just-every/code = latest` | 0.6.177 | npm | `coder` |
| `pipx:black = 26.5.1` | 26.5.1 | pipx | `black`, `blackd` |
| `pipx:conda-lock = 4.0.2` | 4.0.2 | pipx | `conda-lock` |
| `pipx:conda-package-handling = 2.5.0` | 2.5.0 | pipx | `cph` |
| `pipx:docling-slim = 2.123.0` | 2.123.0 | pipx | `docling` and related tools |
| `pipx:markdown-code-runner = 2.7.0` | 2.7.0 | pipx | `markdown-code-runner` |
| `pipx:mypy = 2.3.1` | 2.3.1 | pipx | `mypy`, `dmypy`, `stubgen` |
| `pipx:poethepoet = 0.48.0` | 0.48.0 | pipx | `poe` |
| `pipx:ruff = 0.16.4` | 0.16.4 | pipx | `ruff` |
| `pipx:tuitorial = 0.16.0` | 0.16.0 | pipx | `tuitorial` |
| `pipx:unidep = 3.4.2` | 3.4.2 | pipx | `unidep` |
| `pipx:pre-commit = 4.6.2` | 4.6.2 | pipx | `pre-commit` |
| `npm:@doist/todoist-cli = 4.0.0` | 4.0.0 | npm | `td` |
| `npm:@googleworkspace/cli = 0.22.5` | 0.22.5 | npm | `gws` |
| `npm:tree-sitter-cli = 0.26.13` | 0.26.13 | npm | `tree-sitter` |
| `gh = latest` | 2.99.0 | `aqua:cli/cli` | `gh` |
| `herdr = 0.8.2` | 0.8.2 | `aqua:herdrdev/herdr` | `herdr` |
| `usage = latest` | 6.6.1 | `aqua:jdx/usage` | `usage` |
| `micromamba = 2.9.0-0` | 2.9.0-0 | `github:mamba-org/micromamba-releases` | `micromamba` |

Backend options also match. Rust keeps `profile = "default"`, unidep keeps
`uvx_args = "--with unidep[all]"`, and pre-commit keeps
`uvx_args = "--with pre-commit-uv"` in both declaration and lock.

The 11 direct binary artifacts have SHA-256 checksums. npm, pipx, and Rust
entries do not have artifact URLs or checksums in this lock format because
those backends install through an external package manager or channel. Strict
locked mode skips those backends rather than making them offline or
content-addressed. This behavior matches mise's
[`mise.lock` documentation](https://mise.jdx.dev/dev-tools/mise-lock.html).

A read-only `mup` equivalent found newer resolutions for three floating tools:

| Tool | Committed | Available on 2026-09-02 |
| --- | --- | --- |
| Claude | 2.1.258 | 2.1.259 |
| OpenCode | 1.18.26 | 1.18.27 |
| `@just-every/code` | 0.6.177 | 0.6.178 |

This is expected lockfile drift, not a deployment failure. A normal apply
continues to install the committed versions. Running `mup` advances them.

### Deliberate and accidental command overlap

Linux needs a system Python even when mise owns the user's development Python.
The same pattern applies to Node after `zed` and `bitwarden-cli` pull an Arch
Node package. System scripts retain `/usr/bin`; the repo's shell puts mise
shims first for user commands. Those are deliberate platform/runtime splits.

The following overlap has no such dependency boundary:

| Command | Omarchy owner | mise owner | Active result on the review host |
| --- | --- | --- | --- |
| `herdr` | Omarchy `herdr` 0.8.2 | `aqua:herdrdev/herdr` 0.8.2 | mise shim wins |
| `usage` | Arch `usage` 5.1.0 | `aqua:jdx/usage` 6.6.1 | mise shim wins |
| `tree-sitter` | Arch `tree-sitter-cli` 0.26.9 | `npm:tree-sitter-cli` 0.26.13 | mise shim wins |

The Linux drift hook intentionally excludes `/usr/bin`, so it reports none of
these conflicts.

### Doom and Vim ownership

| Component | Owner | Pinning and update behavior |
| --- | --- | --- |
| Doom core | Custom chezmoi `run_onchange` hook | Git checkout detached at `1404f1bac5a2ae8602b4d861f7805e194c05d28c`; hook refuses to move a dirty checkout |
| Doom packages | Doom's installer under the pinned core checkout | `doom install --aot --no-config --env` runs when the core revision or managed Doom config changes |
| Vim gruvbox | chezmoi archive external | Git commit `697c00291db857ca0af00ec154e5bd514a79191f` |
| Vim nerdcommenter | chezmoi archive external | Git commit `a462bbda1e26f44fb3d3eb9d9d1c6a07aa98e665` |
| Vim nerdtree | chezmoi archive external | Git commit `690d061b591525890f1471c6675bcb5bdc8cdff9` |
| Vim airline | chezmoi archive external | Git commit `192c2c7e8e58fcc771b1959e633b963984319a7c` |
| Vim fugitive | chezmoi archive external | Git commit `3b753cf8c6a4dcde6edee8827d464ba9b8c4a6f0` |
| Vim surround | chezmoi archive external | Git commit `3d188ed2113431cf8dac77be61b842acb64433d9` |

The six Vim URLs are revision-pinned but have no archive checksum. Agent 1's
external and offline findings cover that lifecycle, so this report does not
repeat them as an Agent 4 finding.

## Manual state after package installation

Package installation alone does not finish these tools:

| Tool group | Remaining manual state |
| --- | --- |
| Bitwarden | Desktop or CLI login and unlock |
| Dropbox | Account link and desktop startup behavior |
| Tailscale | Enable/start `tailscaled`, then authenticate with `tailscale up` |
| Ollama | Enable/start `ollama.service` and download chosen models |
| Google Cloud CLI | Account and application-default authentication as needed |
| Slack | Workspace login |
| GitHub CLI | `gh auth login` |
| Claude, Codex, Gemini, OpenCode, Pi, Coder | Provider authentication and onboarding |
| Todoist and Google Workspace CLIs | Account authentication |
| Doom | A second chezmoi apply on Omarchy because Emacs arrives after the Doom hook on the first apply |

Agent 6 owns application-level validation. This table only records the state
that package ownership cannot provide.

## Findings

### A4-001

Finding ID: A4-001

Severity: high

Platform and scenario: Fresh Omarchy 4 account with the stock `tldr` package

Deployment phase: First apply, pacman package transaction

Files and lines: `.chezmoidata/packages.yaml:43`,
`run_after_install-omarchy-packages.sh.tmpl:12-26`; packaged evidence at
`/usr/share/omarchy/install/omarchy-base.packages:123`

Observed behavior: Stock Omarchy installs the `tldr` Python client. The repo
requests `tealdeer`, which provides the same `tldr` command and declares a hard
conflict with the stock package. It does not declare `Replaces: tldr`.
`omarchy pkg add` passes the package batch to `pacman -S --noconfirm --needed`
without first dropping the conflicting package.

Fresh-host consequence: Pacman aborts the package transaction. The Omarchy
package hook fails before the later mise and trust hooks run. The user must
know to remove a stock Omarchy package and apply again.

Reproduction or evidence: The live pacman log records the first transaction
with `tealdeer` at 10:08 and no resulting install. It then records a separate
`pacman -Rns --noconfirm tldr` at 10:09, followed by the same install
transaction and a successful `tealdeer` install. Current package metadata
still says `tealdeer` conflicts with `tldr`, while the Omarchy 4.0.2 base list
still includes `tldr`.

Automated or manual: Automated failure with undocumented manual recovery

Current workaround: Run `omarchy pkg drop tldr`, then apply again.

Recommended change: Decide which client owns `tldr`. The simplest convergent
choice is to keep stock Omarchy's `tldr` package and remove `tealdeer` from the
manifest. If tealdeer is intentional, add a guarded and documented replacement
step before the main package transaction.

Verification: On a fresh Omarchy 4 snapshot, confirm `pacman -Q tldr`, run the
first apply, and require the pacman phase to finish without a manual removal.
Run two more applies and confirm the selected owner remains stable.

Confidence: verified

### A4-002

Finding ID: A4-002

Severity: medium

Platform and scenario: Omarchy 4 after mise installation, then any later
Omarchy or repo tool update

Deployment phase: First apply and ongoing updates

Files and lines: `dot_config/mise/conf.d/10-dotfiles.toml:68,72-73`,
`.chezmoitemplates/shell-path.sh:33-50`; packaged evidence at
`/usr/share/omarchy/install/omarchy-base.packages:52,124,134` and
`/usr/share/omarchy/migrations/1786273938.sh:1-15`

Observed behavior: Omarchy owns `herdr`, `tree-sitter-cli`, and `usage` as
system packages. The repo installs all three again with mise. Its PATH places
mise shims before `/usr/bin`, so pacman upgrades do not control the commands
the user runs. The review host already has different system and mise versions
for `usage` and `tree-sitter`.

Omarchy's Herdr migration is explicit about this risk. It removes the old mise
install because a stale client can shadow the packaged client with an older
wire protocol. This repo reinstalls the exact state that migration removes.

Fresh-host consequence: Disk use is duplicated and update ownership is split.
After an Omarchy update, a stale mise Herdr can break its client/server protocol
until the repo lock is updated. `usage` and `tree-sitter` can also differ from
the versions Omarchy tested with its desktop and editor packages.

Reproduction or evidence: `pacman -Qo` assigns `/usr/bin/herdr`,
`/usr/bin/usage`, and `/usr/bin/tree-sitter` to system packages. `mise which`
returns a different path for each. On the review host, system/mise versions
were 5.1.0/6.6.1 for `usage` and 0.26.9/0.26.13 for `tree-sitter`.

Automated or manual: Automated

Current workaround: Call `/usr/bin/<command>` when the Omarchy version is
required, or keep the repo lock synchronized with every Omarchy update.

Recommended change: Remove `herdr`, `usage`, and `npm:tree-sitter-cli` from the
mise declaration on Omarchy and let the stock packages own them. If the same
shared mise file must serve other platforms, add platform-specific mise
declarations without adding macOS package policy to this report.

Verification: Apply on Omarchy, then require `mise which` not to claim the
three commands. Confirm the bare commands resolve to `/usr/bin` before and
after an Omarchy update. Extend the drift check to compare declared mise
commands with system-owned commands so future overlaps are reported.

Confidence: verified

### A4-003

Finding ID: A4-003

Severity: medium

Platform and scenario: Unofficial or future Omarchy Linux on arm64

Deployment phase: First apply, package and mise installation

Files and lines: `dot_config/mise/mise.lock:7-175`,
`.chezmoitemplates/shell-interactive.sh:108-119`,
`docs/package-lists/mise.md:7-13,37-39`

Observed behavior: Every artifact entry in the committed lock has only a
`linux-x64` platform key. The Linux `mup` function also hardcodes
`--platform linux-x64`. Neither the README nor Linux package document declares
x86_64 as the support boundary.

Fresh-host consequence: On arm64, `mise install --locked` cannot use the 11
lockable artifacts because their current-platform URLs are absent. The
official mise behavior is to fail strict installation when the lock has no URL
for the current platform. Several system packages in the current Omarchy and
personal manifests are also x86_64-only.

Reproduction or evidence: Static inspection found 11 `platforms.linux-x64`
tables, 11 checksums, and no `linux-arm64` table. Mise documents the strict
failure rule and the `linux-arm64` platform key in its
[`mise.lock` documentation](https://mise.jdx.dev/dev-tools/mise-lock.html).
The current official Omarchy install path does not provide a normal arm64 ISO
and repository, so this was not run on a stock arm64 host.

Automated or manual: Undocumented support boundary

Current workaround: Treat Omarchy x86_64 as the only supported Linux target.
An unofficial arm64 user must generate and commit a native lock, replace
unavailable system packages, and use an arm64 package source.

Recommended change: State that Linux support means official Omarchy x86_64.
If arm64 becomes supported, add `linux-arm64` lock entries, make `mup` select
the host platform, and split or replace x86_64-only pacman and AUR packages.

Verification: First follow the documented support policy on an x86_64 stock
image. If arm64 support is chosen later, run the full cold-start protocol on an
official arm64 image and require `mise install --locked` to make no metadata
resolution calls.

Confidence: likely

### A4-004

Finding ID: A4-004

Severity: low

Platform and scenario: Omarchy 4 package-managed mise installation

Deployment phase: Ongoing updates

Files and lines: `README.md:81-85`, `docs/package-lists/mise.md:37-39`;
packaged evidence at `/usr/share/omarchy/install/omarchy-base.packages:80`

Observed behavior: Both documents tell the user to update mise with
`mise self-update`. Omarchy 4 owns `/usr/bin/mise` through `mise-bin`. The
command exits without updating and says self-update is disabled for this
installation.

Fresh-host consequence: The documented update procedure fails. Mise remains
at the system package version until an Omarchy or pacman update installs a
newer package.

Reproduction or evidence: `pacman -Qo /usr/bin/mise` returned
`mise-bin 2026.8.15-1`. `mise self-update` reported that 2026.9.1 was available,
then refused because self-update is disabled. Mise's installation guide says
package-manager installations update through their package manager, while
non-package-manager installations use self-update:
[`Installing mise`](https://mise.jdx.dev/installing-mise.html).

Automated or manual: Incorrect manual instruction

Current workaround: Use `omarchy update` or update `mise-bin` with the system
package manager.

Recommended change: Make the mise update instruction platform-owned. On
Omarchy, tell the user that the normal Omarchy update owns mise. Leave the
macOS wording to the macOS reviewer.

Verification: Follow the revised Omarchy update instruction and confirm
`pacman -Q mise-bin` changes when a newer package is available. Confirm the
documentation no longer calls `mise self-update` on Omarchy.

Confidence: verified

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
omarchy version
uname -m
pacman -Si and pacman -Qi for all 46 system declarations
yay -Si google-cloud-cli slack-desktop
pacman -Qo for active system and mise-shadowed commands
pacman package-file and reverse-dependency comparisons
inspection of /usr/share/omarchy/install and relevant migrations
inspection of /var/log/pacman.log for first package replacement
mise install --dry-run --locked with the repo config and lock
mise lock --global --platform linux-x64 --bump --dry-run --json
mise ls, mise which, and executable-name checks for all 28 declarations
bash -n on the rendered package, mise, and Doom hooks
rendering of the Vim external declaration
comparison of every declaration, lock version, backend, option, platform URL,
and checksum
```

`chezmoi apply --dry-run --refresh-externals=never` was attempted on the live
account, but chezmoi stopped for an interactive answer because the application
had changed `~/.config/opencode/opencode.json`. I did not override that user
state. Agent 1's disposable render already covers target convergence.

## Checks deferred to a disposable cold-start host

The review did not install, remove, upgrade, or interrupt packages on the live
host. These checks remain for the dynamic Omarchy stage:

- first apply with stock `tldr` still installed
- an interrupted pacman transaction and a later recovery apply
- one AUR build failing after the pacman batch succeeds
- a cold mise install with empty data and cache directories
- a cold install with the network disabled
- service startup and authentication for Tailscale, Ollama, and desktop apps
- GPU-specific Ollama behavior on non-NVIDIA hardware
- first, second, and third apply convergence after package state changes

Agent 1 already verified that an optional AUR failure prevents later mise and
trust hooks from running. That shared lifecycle finding is not duplicated here.
