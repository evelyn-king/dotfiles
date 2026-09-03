# Agent 6 deployment review: applications and developer workflows

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-02

Local review host: Omarchy 4.0.2, Linux amd64, chezmoi 2.72.0

## Scope and verdict

This report covers the common and Linux parts of agent 6's workstream. It does
not make claims about macOS rendering, application behavior, paths, prompts, or
permissions. A later macOS reviewer still needs to run those checks on Apple
Silicon.

The Linux workstream is blocked for a fresh Jupyter setup. The repository
installs micromamba and manages two environment files, but no hook creates
either environment. The documented detached Jupyter command also fails before
launch on a pristine account because it redirects output into a state directory
that it has not created yet.

I found seven other problems. An interrupted Doom clone cannot recover on the
next apply, detached Jupyter can report success for a dead process, micromamba
refresh is destructive before the replacement has been tested, the environment
specifications are not reproducible, Neovim has no shared plugin lock, its
headless bootstrap waits forever after a clone failure, and current OpenCode
migrates a managed setting into an unmanaged file.

No configuration files were changed. This report is the only worktree edit.

## Application checks

The checks used the applications installed on the Omarchy review host. Paths
with spaces were exercised under `/tmp/agent 6 review` for rendered files,
Neovim config, data, cache, and state.

| Application | Installed version | Result |
| --- | --- | --- |
| Neovim | 0.12.5 | Headless startup passed with the installed plugin tree. A fresh offline bootstrap timed out after 30 seconds. See A6-007 and A6-008. |
| Vim | 9.2.1001 | Ex-mode startup passed with all six deployed pack plugins. |
| Emacs and Doom | Emacs 31.1, Doom revision `1404f1b` | The three config files passed Lisp reading and parenthesis checks. The hook rendered and passed `bash -n`. The live Doom checkout is clean and at the declared revision. A full fresh sync was not run without a disposable networked host. See A6-004. |
| Git | 2.55.0 | The rendered Linux config passed `git config --file ... --list`. |
| Ghostty | 1.3.1 | The rendered Linux config passed `ghostty +validate-config`. |
| tmux | 3.7c | Static inspection found no unsupported directives. A clean server parse could not run because this review sandbox denies tmux socket creation. |
| Zellij | 0.45.0 | `zellij setup --check` reported `CONFIG FILE: Well defined.` |
| Atuin | 18.19.0 | `atuin config print` parsed the managed config and theme selection. |
| btop | 1.4.7 | The live managed config has no chezmoi drift. btop has no noninteractive config validator. |
| bat | 0.26.1 | The config parsed through `BAT_CONFIG_PATH`; both named Gruvbox themes exist. |
| lazygit | 0.64.1 | YAML and the `overrideGpg` setting were accepted. |
| Claude Code | 2.1.258 | The rendered JSON parsed. `claude doctor` found no installation problem and confirmed that authentication is absent in isolated state. |
| Gemini CLI | 0.58.0 | JSON parsed and the CLI loaded it. The hook input and structured allow/deny output match the [current Gemini hook contract](https://geminicli.com/docs/hooks/reference/). |
| OpenCode | 1.18.26 | The plugin bundled successfully and OpenCode loaded it. The theme setting has moved to another file. See A6-009. |
| micromamba | 2.9.0 | Argument and missing-command checks passed. Neither declared environment exists on the review host. |

The Lua files passed `luac -p`. The three custom Bash scripts passed `bash -n`
and ShellCheck 0.11.0. The rendered Claude and Gemini adapters allowed
`git status` and blocked `git push --force origin main` using each CLI's expected
protocol. OpenCode loaded the TypeScript plugin from the deployed config, and a
standalone Bun build also passed.

## Findings

### A6-001

Finding ID: A6-001

Severity: high

Platform and scenario: Linux, fresh account after mise has installed
micromamba

Deployment phase: First use of the documented remote Jupyter workflow

Files and lines: `README.md:151-176`,
`local-codex/environments/jupyter_environment.yml:1-33`,
`local-codex/environments/analysis_environment.yml:1-39`,
`dot_local/bin/executable_install-micromamba-env:134-171`

Observed behavior: Chezmoi manages two environment specifications and the
installer script, but no apply hook calls the installer. The README goes
straight to `jupyter-remote-lab`. It does not tell the user to create the
`jupyter` environment first.

Fresh-host consequence: `jupyter-remote-lab` cannot start. Micromamba exits
because `~/.local/opt/micromamba/envs/jupyter` does not exist. The `analysis`
environment is also absent, so the local Codex analysis environment is data on
disk rather than an available runtime.

Reproduction or evidence: `micromamba env list` on the review host listed only
`base`. `micromamba run -n jupyter jupyter --version` failed with `The given
prefix does not exist`. A repository search found no hook or bootstrap command
that invokes `install-micromamba-env`.

Automated or manual: Undocumented manual work

Current workaround: Run
`install-micromamba-env ~/local-codex/environments/jupyter_environment.yml`.
Run it again with `analysis_environment.yml` if the analysis environment is
wanted.

Recommended change: Either add an idempotent apply hook for the declared
environments or document environment creation as a required post-apply step.
Do not automate it until A6-005 is fixed, because the current installer removes
a working environment before proving that its replacement can be built.

Verification: On a disposable fresh Linux account, apply the dotfiles, create
the declared environments by the chosen method, verify both kernels with
`jupyter kernelspec list`, then start and stop `jupyter-remote-lab` in foreground
and detached modes.

Confidence: verified

### A6-002

Finding ID: A6-002

Severity: high

Platform and scenario: Common script path, first detached Jupyter launch when
the state directory does not exist; reproduced on Linux, macOS not tested

Deployment phase: First use

Files and lines: `dot_local/bin/executable_jupyter-remote-lab:110-144`,
`dot_local/bin/executable_jupyter-remote-lab:252-255`

Observed behavior: Detached mode redirects stdout and stderr to
`${STATE_DIR}/jupyter-${PORT}.log` and writes the PID file before
`write_runtime_env` calls `mkdir -p "${STATE_DIR}"`.

Fresh-host consequence: The documented `--detach` command exits 1 without
starting Jupyter. Neither the log nor the PID file can be created.

Reproduction or evidence: With a new `JUPYTER_STATE_DIR`, the script returned
`No such file or directory` for both `jupyter-8888.log` and
`jupyter-8888.pid`, then exited 1.

Automated or manual: Automated command with a deterministic first-run failure

Current workaround: Create `~/.local/state/jupyter-remote` before the first
detached launch.

Recommended change: Create and validate `STATE_DIR` and the parent of
`JUPYTER_REMOTE_ENV_FILE` before starting the background process or opening any
redirection.

Verification: Point `JUPYTER_STATE_DIR` and `JUPYTER_REMOTE_ENV_FILE` at absent
paths, run detached mode, and confirm that the directories, log, PID file, and
runtime environment file are created without preparatory commands.

Confidence: verified

### A6-003

Finding ID: A6-003

Severity: medium

Platform and scenario: Common script path, detached Jupyter launch with a
missing environment or another immediate startup error; reproduced on Linux,
macOS not tested

Deployment phase: Application launch

Files and lines: `dot_local/bin/executable_jupyter-remote-lab:252-266`

Observed behavior: The script backgrounds the environment runner, records
`$!`, writes runtime metadata, prints `Started JupyterLab`, and exits 0. It
never checks whether the child survived or opened the requested port.

Fresh-host consequence: The command reports success and gives the user an SSH
tunnel command even though no server is listening. The PID and runtime files
describe a dead process.

Reproduction or evidence: After pre-creating the state directory, I launched
with `JUPYTER_ENV_NAME=definitely-missing-agent6`. The launcher exited 0 and
printed `Started JupyterLab`; the recorded process was already dead and the log
said that the environment prefix did not exist.

Automated or manual: Automated

Current workaround: Inspect the log and verify the PID or port after every
detached launch.

Recommended change: Validate that the selected environment contains
`jupyter`, then poll the child and listening port for a short bounded period.
Write current runtime metadata and print the success message only after the
process passes that check. Return nonzero with the last log lines when it dies.

Verification: Test a valid environment, a missing environment, a missing
`jupyter` executable, and a port already in use. Only the valid launch should
exit 0 or leave current metadata.

Confidence: verified

### A6-004

Finding ID: A6-004

Severity: high

Platform and scenario: Common hook path, power loss or hard interruption during
the initial Doom clone; reproduced as an incomplete checkout on Linux, macOS
not tested

Deployment phase: Doom bootstrap and recovery

Files and lines: `run_onchange_after_install-doom-emacs.sh.tmpl:26-55`

Observed behavior: The hook clones directly into `~/.config/emacs`. On a later
run, the presence of `~/.config/emacs/.git` is enough to skip cloning. If that
directory is incomplete and has no valid `HEAD`, `git rev-parse HEAD` fails.
The following `git diff` failure is reported as uncommitted work, so every retry
stops without repairing the checkout.

Fresh-host consequence: Doom remains unavailable after later applies. The
message tells the user to clean changes that do not exist and gives no safe
recovery command.

Reproduction or evidence: I created an isolated home containing only
`~/.config/emacs/.git` and ran the rendered hook. Git reported `not a git
repository`; the hook then printed `has uncommitted changes` and exited 1.

Automated or manual: Automated failure followed by undocumented manual recovery

Current workaround: Inspect the path, remove the incomplete clone only after
confirming that it contains no user work, then apply again.

Recommended change: Clone and check out the pinned revision in a sibling
temporary directory owned by this hook. Validate `HEAD`, the remote, and
`bin/doom`, then rename it into place. Detect an invalid existing `.git`
directory separately from a dirty valid checkout and print a truthful recovery
message.

Verification: Interrupt clone after destination creation, rerun the hook, and
confirm automatic recovery. Also test a valid checkout at the wrong revision,
a dirty valid checkout, an untracked-file conflict, interrupted `doom install`,
and a quiet second apply.

Confidence: likely

### A6-005

Finding ID: A6-005

Severity: medium

Platform and scenario: Common script path, refresh of an existing micromamba
environment when solving, downloading, extraction, or kernel installation
fails; inspected on Linux, macOS not tested

Deployment phase: Developer environment refresh

Files and lines: `dot_local/bin/executable_install-micromamba-env:81-132`,
`dot_local/bin/executable_install-micromamba-env:164-170`

Observed behavior: For each input file, the installer removes the existing
kernel and environment before it runs `micromamba env create`. `set -e` stops
the script on a failed create or kernel install, but it cannot restore what was
removed.

Fresh-host consequence: This does not hurt the first build, but any later
refresh can turn a working environment into no environment at all. Recovery
requires another full solve and download after the original problem is fixed.

Reproduction or evidence: The command order is unconditional at lines 166-170.
`remove_kernel_if_present` and `remove_env_if_present` complete before
`install_env`; no backup, staging prefix, solve-only check, or rollback exists.

Automated or manual: Manual command with destructive automated steps

Current workaround: Export the environment or keep its package cache, then
rerun the installer after fixing the solver or network failure.

Recommended change: Solve and build into a staging prefix first. Replace the
old environment and kernel only after the new Python and `ipykernel` pass a
smoke test. At minimum, run a locked dry solve before removal and postpone
kernel removal until the new environment exists.

Verification: Begin with a working environment and kernel, inject failures at
solve, download, extraction, and kernel-install phases, and confirm that the
old environment remains usable after each failure.

Confidence: verified

### A6-006

Finding ID: A6-006

Severity: medium

Platform and scenario: Common environment files, creation or recreation at
different dates; inspected on Linux, macOS not tested

Deployment phase: Developer environment installation

Files and lines: `dot_mambarc:1-4`,
`local-codex/environments/jupyter_environment.yml:1-33`,
`local-codex/environments/analysis_environment.yml:1-39`

Observed behavior: Both environment files name packages without versions or
builds. Pip dependencies are also unpinned. `.mambarc` explicitly sets
`use_lockfiles: false`, and the repository contains no conda lock for either
environment.

Fresh-host consequence: Two fresh hosts can receive different Python, Jupyter,
Dask, NumPy, and pip dependency sets. Recreating an environment later can
change every one of those packages while keeping the same repository commit.
That makes failures hard to reproduce and magnifies A6-005.

Reproduction or evidence: Neither YAML file has a version constraint. The
Jupyter file declares 26 conda packages and two pip packages; the analysis file
declares 30 conda packages and four pip packages. No matching lock file is
tracked.

Automated or manual: Manual and nondeterministic

Current workaround: Export an explicit environment before refresh and retain
the package cache.

Recommended change: Generate platform-specific conda locks for supported Linux
architectures and install from them. Keep the human-edited YAML files as inputs
if desired, but make the deployment command consume the reviewed lock.

Verification: Build twice from the same lock in clean prefixes and compare
`micromamba list --explicit` plus the installed kernels. The outputs should
match.

Confidence: verified

### A6-007

Finding ID: A6-007

Severity: medium

Platform and scenario: Common Neovim config, first launch or plugin refresh;
runtime behavior reproduced on Linux, macOS not tested

Deployment phase: Editor bootstrap

Files and lines: `.gitignore:1`, `dot_config/nvim/lua/config/lazy.lua:17-27`

Observed behavior: The repository ignores
`dot_config/nvim/lazy-lock.json`. Lazy's default lock is generated at
`~/.config/nvim/lazy-lock.json`, but chezmoi never supplies it to another host.
The config also sets `version = false`, so plugin specs resolve branch heads or
other current commits rather than release versions.

Fresh-host consequence: A fresh host resolves a different set of plugin
commits from an existing host. Plugin compatibility and headless-start results
can change without a dotfiles commit.

Reproduction or evidence: No lock is tracked. The review host has a generated
6,019-byte lock with 63 plugin revisions, all absent from the source state. A
fresh isolated launch immediately attempted to clone from GitHub.

Automated or manual: Automated and intentionally untracked

Current workaround: Copy the lock from a working host before first launch, or
accept the current dependency set and debug breakage after resolution.

Recommended change: Track the Neovim lock in the chezmoi source state and
define an explicit update command or cadence. The repository guideline that
requires it to remain untracked must change if reproducible editor deployment
is the goal.

Verification: Launch Neovim in two clean homes from the same commit and confirm
that their lock files and checked-out plugin revisions match byte for byte.

Confidence: verified

### A6-008

Finding ID: A6-008

Severity: medium

Platform and scenario: Common Neovim config, headless first launch with DNS,
network, GitHub, or clone failure; reproduced on Linux, macOS not tested

Deployment phase: Editor bootstrap and smoke testing

Files and lines: `dot_config/nvim/lua/config/lazy.lua:1-13`

Observed behavior: When cloning `lazy.nvim` fails, the bootstrap prints the
error and calls `vim.fn.getchar()` before exiting. A headless process has no key
to provide.

Fresh-host consequence: An automated editor smoke test hangs instead of
returning the clone failure. CI and cold-start scripts need an external timeout,
which hides the useful exit status.

Reproduction or evidence: In a clean data directory with network resolution
unavailable, Neovim printed `Failed to clone lazy.nvim` and `Press any key to
exit...`. It remained alive until `timeout 30s` sent SIGTERM.

Automated or manual: Automated

Current workaround: Wrap headless startup in `timeout` and inspect combined
output.

Recommended change: Call `getchar()` only when a UI is attached. In headless
mode, print the clone output and exit nonzero immediately.

Verification: Force clone failure in interactive and headless modes. The
interactive session may wait for acknowledgement; the headless command must
return nonzero without a timeout.

Confidence: verified

### A6-009

Finding ID: A6-009

Severity: medium

Platform and scenario: Linux with OpenCode 1.18.26; the migration is common to
current OpenCode releases, but macOS was not tested

Deployment phase: First OpenCode launch after the TUI config migration, then
every later chezmoi apply

Files and lines: `dot_config/opencode/opencode.json:1-5`, `README.md:119-121`

Observed behavior: OpenCode moved the TUI theme from `opencode.json` to
`tui.json`. The live application created `tui.json`, saved
`opencode.json.tui-migration.bak`, and removed `theme` from the managed
`opencode.json`. Chezmoi still renders the old file, so `chezmoi status` reports
`MM .config/opencode/opencode.json`.

Fresh-host consequence: OpenCode and chezmoi take turns rewriting the setting.
The intended theme works only because an unmanaged migrated `tui.json` remains
on this host. A fresh apply can restore a stale input that OpenCode must migrate
again.

Reproduction or evidence: `opencode debug config` omitted the source file's
`theme` key. The deployed config lacks that key, while the application-created
`~/.config/opencode/tui.json` contains `"theme": "system"` and the migration
backup contains the original managed JSON. Current OpenCode theme documentation
places the setting in `tui.json`: <https://opencode.ai/docs/themes>.

Automated or manual: Automated application migration and automated chezmoi
restore

Current workaround: Leave the unmanaged `tui.json` in place and tolerate the
managed-file drift.

Recommended change: Remove `theme` from the managed runtime config and add a
managed `dot_config/opencode/tui.json` with the TUI schema and system theme.
Decide whether the migration backup should remain unmanaged or become a
one-time cleanup item.

Verification: Apply into a clean home, launch OpenCode once, and confirm that
the next `chezmoi status` is empty and no migration backup appears.

Confidence: verified

## Generated and application-owned state

| Path | Owner and behavior | Chezmoi conflict |
| --- | --- | --- |
| `~/.config/nvim/lazy-lock.json` | lazy.nvim records 63 resolved plugin revisions on the review host. | Deliberately absent from source, so no direct overwrite. It causes A6-007 instead. |
| `~/.local/share/nvim`, `~/.cache/nvim`, `~/.local/state/nvim` | Neovim and its plugins create checkouts, cache, logs, and persistent state. | None observed. |
| `~/.config/emacs` | The Doom hook owns the Git checkout. Doom writes packages and generated files below its `.local` tree. | Chezmoi owns `~/.config/doom`, not the checkout. Partial checkout recovery is broken in A6-004. |
| `~/.config/opencode/tui.json` and `opencode.json.tui-migration.bak` | OpenCode's TUI migration creates both. | The source still writes the migrated key to `opencode.json`, causing A6-009. |
| `~/.config/opencode/package.json`, lock files, and `node_modules` | OpenCode installs its plugin SDK beside the managed plugin. | No direct overwrite observed, but this is application-written state inside a partly managed directory. |
| `~/.local/share/atuin` | Atuin owns history databases, encryption material, and sync state. | None observed. Do not add these files to chezmoi. |
| `~/.local/state/jupyter-remote` | The launcher owns logs, PID files, and `current.env`. | Unmanaged as intended. Creation and liveness are broken in A6-002 and A6-003. |
| `~/.vim/undo-dir` | Vim writes persistent undo files. | Chezmoi creates the directory with `.gitkeep`; no file conflict observed. |
| `~/local-codex/screenshots` | Chezmoi creates the directory with `.gitkeep`; applications own its contents. | No conflict observed. |

The live `chezmoi status` check found drift only in
`~/.config/opencode/opencode.json` among the in-scope paths.

## Manual state and onboarding

| Item | State after apply | Classification |
| --- | --- | --- |
| Claude Code | The CLI and settings are installed. The isolated doctor reported no credentials. The selected Opus model also depends on account entitlement. | Undocumented manual authentication |
| Gemini CLI | Settings select `gemini-api-key`; the CLI refuses to continue until `GEMINI_API_KEY` is supplied. | Undocumented manual authentication and secret placement |
| OpenCode | Config and plugin are installed, but no provider credential is provisioned. | Undocumented manual authentication |
| Atuin | Local history works. Sync needs account login plus restoration or safe retention of the encryption key. | Undocumented manual authentication and key restoration |
| Git and lazygit | Git requires the declared GPG secret key and working pinentry for commits. Lazygit inherits that requirement. | Undocumented manual key restoration; agent 7 owns the security review |
| Jupyter and analysis environments | YAML and helper scripts are installed, but the environments and kernels are not. | Undocumented manual setup, A6-001 |
| Doom | The hook automates clone, checkout, package sync, and environment capture once Git and Emacs exist. It still needs network access to Git hosts. | Automated after prerequisites, with recovery gap A6-004 |
| Ollama | Package installation is outside this workstream. No reviewed agent 6 file starts the service or downloads a model. | Manual service and model setup; route to agents 3 and 4 |
| Ghostty, tmux, Zellij, btop, bat, and Vim | No account, model, or license onboarding was found. | Automated config, subject to package installation by other workstreams |

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
chezmoi status filtered to agent 6 paths
chezmoi execute-template for Git, Ghostty, Claude, Gemini, and Doom files
git config parsing of the rendered Linux config
ghostty +validate-config on the rendered Linux config
zellij setup --check
atuin config print
BAT_CONFIG_PATH=<managed config> bat --list-themes
headless Vim startup with all deployed pack plugins
headless Neovim startup with the installed plugin tree
headless Neovim first start with clean data and forced network failure
luac -p on every Neovim Lua file
Emacs Lisp read and parenthesis checks on the Doom config
bash -n and ShellCheck on all three custom scripts
missing-command, missing-argument, invalid-port, invalid-path, and path-with-spaces script checks
fresh and pre-created Jupyter state-directory tests
dead detached Jupyter child test
incomplete Doom checkout recovery test in an isolated home
Claude doctor with isolated rendered settings
Gemini config load and hook-protocol checks
Claude and Gemini allow and deny adapter checks
Bun build and OpenCode load of the TypeScript plugin
OpenCode config migration and live chezmoi drift inspection
```

The review did not install or remove a real micromamba environment, fetch
Neovim or Doom dependencies, start an interactive terminal multiplexer, log in
to an agent service, or run a macOS application. Those tests need disposable
hosts with network access and, for terminal UI checks, an unrestricted PTY.
