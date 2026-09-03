# Deployment review plan

This plan evaluates the dotfiles for deployment on a new Apple Silicon macOS
host and a new Omarchy host. It focuses on failed or incomplete bootstrap,
undocumented manual work, destructive behavior, ownership conflicts, host
assumptions, and failure to converge after repeated applies.

Run the review in three stages:

1. Freeze the candidate revision and inventory its deployment behavior.
2. Run the static workstreams in parallel.
3. Test cold starts on disposable macOS and Omarchy systems, then combine the
   evidence into platform-specific verdicts.

Static rendering on Linux cannot substitute for the macOS test. Chezmoi uses
built-in OS, architecture, hostname, environment, and filesystem data when it
selects targets and renders templates.

## Review target

Before assigning work, the coordinator must record:

```bash
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
```

The final report must name the exact reviewed commit. If the review runs on a
feature branch, rerun the relevant checks against the commit that lands on
`main`.

Reviewers must not edit the shared worktree. Proposed changes belong in the
final patch queue after the findings have been combined and ranked.

## Completion criteria

The review is complete when it has:

- Reconstructed both deployment sequences from stock OS to usable workstation.
- Distinguished automated setup, undocumented manual work, and intentionally
  unmanaged state.
- Tested first apply, prerequisite installation, reboot or login, second apply,
  and a final no-op apply.
- Verified that persistent migration rules cannot delete unrelated user data.
- Checked current nix-darwin, Homebrew, Omarchy, Hyprland, Ghostty, mise, and
  application compatibility.
- Produced a package ownership table with no accidental duplicate owners.
- Classified every finding as verified, host-dependent, or hypothetical.
- Issued separate macOS and Omarchy verdicts: `ready`,
  `ready with documented manual steps`, or `blocked`.

## Finding format

Each reviewer must use this schema:

```text
Finding ID:
Severity: blocker | high | medium | low
Platform and scenario:
Deployment phase:
Files and lines:
Observed behavior:
Fresh-host consequence:
Reproduction or evidence:
Automated or manual:
Current workaround:
Recommended change:
Verification:
Confidence: verified | likely | hypothesis
```

Severity means:

- `blocker`: prevents deployment, risks data loss, or leaves the host unsafe.
- `high`: breaks a core workflow or requires undocumented recovery.
- `medium`: produces drift, inconsistent behavior, or avoidable manual work.
- `low`: documentation, polish, or maintainability issue with no immediate
  deployment failure.

Keep verified failures separate from leads that still need reproduction. The
coordinator should merge shared findings instead of reporting the same cause
once per platform.

## Parallel static workstreams

### Agent 1: chezmoi bootstrap and lifecycle

Own:

- `.chezmoi.toml.tmpl`
- `.chezmoiignore.tmpl`
- `.chezmoiremove`
- `.chezmoidata/**`
- `run_*.tmpl`
- `.chezmoiexternal.toml.tmpl` files
- `README.md`

Tasks:

1. Build a target-selection matrix for Apple Silicon macOS, Omarchy 4,
   legacy Omarchy 3, dev-linked Omarchy, generic Linux, and an unknown Omarchy
   hostname.
2. List every managed, ignored, removed, externally fetched, and
   script-generated path.
3. Establish the actual hook rendering and execution order. Determine whether
   commands installed by one hook can affect templates or hooks in the same
   apply.
4. Test dependency transitions where mise, Git, Emacs, bun, uv, Nix, or
   nix-darwin are absent on the first apply and present later.
5. Determine whether skipped hooks rerun automatically or require another
   command, template change, or manual intervention.
6. Audit `.chezmoiremove` as persistent deletion policy. Identify migration
   entries that should expire or become guarded one-time operations.
7. Test externals with an empty cache, a populated cache, and no network.
8. Produce the shared first-apply dependency graph and apply timeline.

### Agent 2: macOS and nix-darwin

Own:

- `nix/flake.nix`
- `nix/flake.lock`
- `run_after_darwin-rebuild.sh.tmpl`
- `dot_config/aerospace/**`
- macOS branches in Ghostty, Git, Cargo, and shell templates
- `docs/package-lists/macos.md`

Tasks:

1. Reconstruct installation of Xcode Command Line Tools, Homebrew, Determinate
   Nix, chezmoi, and the first nix-darwin generation.
2. Evaluate the flake without changing its lock.
3. Check every Nix package and Homebrew cask for current availability, Apple
   Silicon support, Rosetta requirements, license prompts, privileged
   installers, and sign-in requirements.
4. Verify the hardcoded username, architecture, and `macbook` configuration
   assumptions.
5. Compare Nix, Homebrew, and mise ownership. Flag duplicate commands and
   undeclared runtime dependencies.
6. Test `homebrew.onActivation.cleanup = "uninstall"` against manually
   installed software and check how greedy cask upgrades interact with
   application self-updaters.
7. Test the drift hook before and after `/run/current-system` exists, including
   evaluation failures and individual output differences.
8. Validate AeroSpace startup, Accessibility approval, application paths,
   reload behavior, and hotkey conflicts.
9. Test a source checkout path containing spaces.

### Agent 3: Omarchy integration

Own:

- `.chezmoitemplates/omarchy-detect.tmpl`
- Omarchy branches in `.chezmoiignore.tmpl` and Ghostty
- `.chezmoidata/packages.yaml`
- `run_after_install-omarchy-packages.sh.tmpl`
- `dot_config/hypr/**`
- Omarchy-specific shell integration
- `docs/package-lists/omarchy-linux.md`

Tasks:

1. Build a detection truth table for the packaged Omarchy 4 root, legacy
   Omarchy 3 root, a valid dev link, stale or invalid `OMARCHY_PATH`, generic
   Linux, and a partial installation.
2. Confirm which targets chezmoi manages in each case and whether Ghostty takes
   the matching branch.
3. Compare the repo-owned Hypr files with the current packaged defaults under
   `/usr/share/omarchy/`. Read that tree, but never edit it.
4. Inspect current Omarchy migrations that touch managed Hypr or Ghostty files.
5. Confirm that required unmanaged modules such as `input.lua` and
   `autostart.lua` exist for a fresh account.
6. Audit every keybinding against the current packaged bindings. Verify each
   prior binding, unbind, launch command, application class, and collision.
7. Validate monitor connectors, modes, fractional scaling, hostname selection,
   dock behavior, and the unknown-host fallback.
8. Document conflicts between chezmoi and `omarchy refresh hyprland`, monitor
   scaling commands, or package migrations.
9. Classify each package by repository, AUR, hardware dependency, service
   requirement, and authentication requirement.
10. Compare the replacement shell startup with the current Omarchy Bash
    bootstrap, functions, aliases, and completions.
11. Validate Ghostty parsing, font resolution, scaling, theme behavior, and
    intentional differences from the packaged default.

Record `omarchy version` before comparing packaged files. Run refreshes,
reloads, package installs, theme changes, and monitor changes only in a
disposable snapshot.

### Agent 4: package and runtime ownership

Own the cross-platform inventory across:

- `nix/flake.nix`
- `.chezmoidata/packages.yaml`
- `dot_config/mise/conf.d/10-dotfiles.toml`
- `dot_config/mise/mise.lock`
- Doom and Vim external declarations

Tasks:

1. Map every command and application to Nix, Homebrew, pacman, AUR, mise,
   application self-update, or manual installation.
2. Flag duplicate owners, bootstrap-only packages that remain installed, and
   commands referenced by configuration but supplied nowhere.
3. Compare each mise declaration with its lock entry, backend, options,
   checksum, platform key, and installed executable name.
4. Check whether Intel Mac and Linux ARM are intentionally unsupported.
5. Review floating `latest` entries, channel-based tools, macOS resolution
   without the committed Linux lock, and the release-age exceptions.
6. Test unavailable versions, missing checksums, offline installation, AUR
   failure, and recovery from a partially completed install.
7. Reconcile update instructions with package ownership. In particular,
   determine whether `mise self-update` is valid when Nix or pacman owns mise.

### Agent 5: shell and session behavior

Own:

- `.chezmoitemplates/shell-*.sh`
- `dot_zsh*`
- `dot_bash*`
- `dot_profile.tmpl`
- `dot_direnvrc`
- `local-projects/dot_mise.toml`

Test:

- Login and non-login zsh.
- Interactive and noninteractive zsh.
- Login and non-login Bash.
- Bash with and without the zsh handoff.
- SSH commands with a minimal inherited `PATH`.
- Cron, launchd, and systemd-user style environments.
- Forwarded and local SSH agents.
- Missing optional tools.
- Source checkout and home paths containing spaces.

Verify PATH ordering, duplicate removal, mise activation, micromamba, Cargo,
Homebrew, Nix, Doom, Pixi, locale handling, `TMPDIR`, completion startup,
command hashing, and per-machine overrides. Check that an override works in
every context where the documentation claims it works.

### Agent 6: applications and developer workflows

Own:

- Neovim, Vim, Doom, Git, Ghostty, tmux, Zellij, Atuin, btop, bat, and lazygit
- Claude, Gemini, and opencode
- Jupyter and micromamba scripts
- local Codex environment files

Tasks:

1. Parse each configuration with the installed application where possible.
2. Run headless editor startup and plugin bootstrap tests.
3. Identify generated or application-rewritten files that will fight chezmoi.
4. Check the consequences of leaving Neovim's lockfile untracked.
5. Test Doom's fresh clone, pinned checkout, dirty checkout, interrupted sync,
   and second run.
6. Verify creation of micromamba environments, Jupyter state directories,
   screenshot directories, undo directories, and other runtime state.
7. Test the custom scripts with missing commands, invalid arguments, paths with
   spaces, interrupted processes, and repeated execution.
8. List authentication, onboarding, model downloads, license acceptance, and
   service startup that the repo cannot automate.

### Agent 7: safety, privacy, and migration policy

Own:

- `.chezmoiremove`
- Git signing and credential settings
- Agent command hooks and their shared policy
- `.mailmap`, `.gitignore`, and tracked identity data
- Documentation of keys, credentials, and permissions

Tasks:

1. Scan for secrets, internal infrastructure, tokens, private keys, unsafe
   permissions, and machine-specific paths.
2. Distinguish public key fingerprints and identities from secret signing
   material, then reconcile them with repository policy.
3. Verify Git behavior when the signing key, GPG executable, or pinentry is
   absent.
4. Inventory SSH and GPG restoration steps.
5. Review automatic mise trust, sourced local files, downloaded code, and
   executable hooks.
6. Run the git rewrite-policy tests and inspect bypass cases.
7. Decide which persistent migration removals should expire or become guarded.
8. Inventory macOS privacy approvals and Linux service permissions.

## Common safe checks

These checks do not intentionally change the deployed home:

```bash
git status --short --branch
git rev-parse HEAD
git diff --check

chezmoi data
chezmoi source-path
chezmoi ignored
chezmoi managed
chezmoi apply --dry-run --force --verbose --refresh-externals=never

chezmoi execute-template --file dot_bashrc.tmpl | bash -n
chezmoi execute-template --file dot_zshrc.tmpl | zsh -n
chezmoi execute-template --file dot_zshenv.tmpl | zsh -n

for file in run_*.tmpl; do
  chezmoi execute-template --file "$file" | bash -n
done

python3 .chezmoitemplates/test_git_rewrite_policy.py
MISE_CONFIG_DIR="$PWD/dot_config/mise" mise install --dry-run --locked
```

Use an isolated destination when inspecting pristine target state:

```bash
review_dir="$(mktemp -d /tmp/chezmoi-review.XXXXXX)"
chezmoi \
  --destination "$review_dir/home" \
  --persistent-state "$review_dir/state.db" \
  apply --dry-run --force --verbose --refresh-externals=never
```

Do not use data overrides to pretend that Linux is macOS. They do not reproduce
the full set of built-in values or filesystem conditions.

### Additional macOS checks

```bash
flake="$(chezmoi source-path)/nix"
nix flake metadata --no-write-lock-file "$flake"
nix flake check --no-write-lock-file "$flake"
nix build --dry-run --no-link \
  "$flake#darwinConfigurations.macbook.system"
nix eval --json \
  "$flake#darwinConfigurations.macbook.config.homebrew.casks"
```

Validate rendered Ghostty and AeroSpace configuration with their installed
versions. Record Accessibility, screen-recording, automation, login-item, and
Rosetta prompts.

### Additional Omarchy checks

```bash
omarchy version
omarchy commands --json
omarchy debug --no-sudo --print
omarchy menu keybindings --print

hyprctl monitors all
hyprctl configerrors
rg -n '\.config/hypr|\.config/ghostty' /usr/share/omarchy/migrations

luac -p dot_config/hypr/hyprland.lua \
  dot_config/hypr/bindings.lua \
  dot_config/hypr/looknfeel.lua
fc-match 'JetBrainsMono Nerd Font'
```

Render `monitors.lua.tmpl` for syntax checking. Check package availability with
pacman and the configured AUR helper, but install packages only in the
disposable cold-start system.

## Dynamic cold-start protocol

Use snapshots or disposable accounts. Preserve the full command transcript,
exit status, prompts, elapsed time, downloads, and state changes for each
phase. A successful `chezmoi apply` does not count as successful deployment if
required setup silently skipped.

### Apple Silicon macOS

Test these states separately:

1. Stock macOS.
2. Chezmoi present, with Nix and Homebrew absent.
3. Nix and Homebrew present, with nix-darwin never activated.
4. First `chezmoi init` and dry run.
5. First actual apply.
6. First nix-darwin activation.
7. Second apply after packages become available.
8. Logout or reboot.
9. GUI, shell, signing, editor, and package smoke tests.
10. Third apply, which should produce no changes or prompts.

Also run a negative test with a short username other than `evelyn`. Exercise
the nix-darwin drift hook with no command, no current generation, an evaluation
failure, a matching generation, and individual output differences.

### Omarchy

Test the current stock Omarchy release with an unknown hostname. Test named
monitor profiles only on matching hardware.

1. Record the Omarchy version, hardware, and packaged defaults.
2. Confirm whether stock Omarchy supplies chezmoi.
3. Run init and dry-run before installing anything else.
4. Run the first apply and record privilege prompts, package batching, AUR
   behavior, downloads, and skipped hooks.
5. Reboot into Hyprland.
6. Check configuration errors, keybindings, monitors, Ghostty, shell startup,
   services, and application launch commands.
7. Run the second apply.
8. Exercise an interrupted package installation and recovery.
9. Confirm that the third apply is quiet.
10. Separately test the intended response to Omarchy refresh and monitor
    scaling commands.

## Manual-state inventory

Both platform reviewers must classify each item as automated, documented
manual work, or undocumented manual work:

- SSH key creation or restoration.
- GPG secret-key import, trust, and pinentry.
- GitHub, Google Cloud, agent CLI, Atuin, Dropbox, Tailscale, Bitwarden, and
  1Password authentication.
- macOS Accessibility, screen-recording, automation, and login-item approval.
- Container runtime initialization.
- Ollama service setup and model downloads.
- Micromamba environment creation.
- Application onboarding and license acceptance.
- Host-specific monitor and input configuration.
- Any logout, reboot, service restart, or application restart.

## Initial review leads

These are questions to reproduce, not accepted findings:

- The documentation begins at `chezmoi apply` rather than a stock-host
  bootstrap.
- The macOS username, architecture, and flake configuration name are hardcoded.
- Linux mise locking is fixed to `linux-x64`.
- `.chezmoiremove` contains persistent deletions of real user paths.
- Hooks that skip absent prerequisites may make another apply necessary.
- The nix-darwin drift hook may not handle a missing current generation.
- Homebrew cleanup may remove manually installed applications.
- Mandatory Git signing has no key-restoration runbook.
- The rendered `nix-switch` alias may mishandle a source path containing spaces.
- Jupyter defaults may overwrite inherited values before the interactive local
  override runs.
- A CUDA-specific Ollama package applies to every Omarchy host.
- A display-specific Hyprland aspect ratio applies to every Omarchy host.
- Omarchy monitor scaling edits a chezmoi-managed file that a later apply may
  restore.
- AeroSpace is configured not to start at login and requires Accessibility
  approval.
- Neovim's untracked lockfile allows fresh hosts to resolve different plugin
  revisions.

## Final synthesis

The coordinator must produce:

- Separate macOS and Omarchy readiness verdicts.
- Findings sorted by severity and deployment phase.
- Exact cold-start runbooks for both platforms.
- A package and tool ownership matrix.
- A target-selection matrix.
- A first-apply hook timeline.
- A table of unavoidable manual steps and approvals.
- First, second, and third apply transcripts.
- A patch queue ordered by deployment risk.

Do not begin remediation until the findings have been deduplicated and the
owner has resolved policy questions such as supported architectures, persistent
migrations, package cleanup, and which host-specific choices belong in the
repository.
