# Deployment review summary

## Review state

The nine agent reports contain 93 findings, with substantial overlap. This
document combines them into one remediation queue.

The reports reviewed source commits `30923db` and `abb2e56`. The latter added
only review documents. The remediation table below records changes made after
the review.

All four P0 findings and all ten P1 findings are resolved.

The files-only chezmoi target set did converge in disposable homes. The main
failures sit at removal, package installation, system activation, and first-use
boundaries.

## Remediation priorities

`P0` means the issue must be resolved before another live apply or system
activation. It does not replace the severity recorded in the source reports.

| Priority | Status | Consolidated finding | Required resolution | Review IDs |
| --- | --- | --- | --- | --- |
| P0 | Resolved | `.chezmoiremove` could recursively delete unrelated or newly recreated user data. | The persistent rules have been removed. Three conflicting config locations now use exact SHA-256 checks and preserve unrecognized content. | A1-001, A7-001, A3-012 |
| P0 | Resolved | The macOS flake hardcoded user `evelyn`, which did not match the owner's account. | `system.primaryUser` is now set for the `macbook` host as `evelynking`. | A2-001, A4M-003 |
| P0 | Resolved | `terraform` was unfree, but the flake had no license exception, so the configuration could not evaluate. | Terraform has been removed from the macOS system package set. | A2-002, A4M-001 |
| P0 | Resolved | Homebrew activation uses `--force-cleanup`, which removes every undeclared formula, cask, and tap. | The flake now documents intentional ownership of the entire Homebrew prefix. | A2-004, A4M-004 |
| P1 | Resolved | Neither platform had a complete cold-start procedure. | The cold-start guide now covers prerequisites, source initialization, activation order, login or reboot, three applies, manual handoffs, and final checks for macOS and Omarchy. | A1-002, A1-005, A2-006, A3-011, A4M-002 |
| P1 | Resolved | The nix-darwin drift hook hid evaluation errors and failed before the first generation existed. | The hook now gives the first-activation command when no generation exists. Evaluation errors remain visible and make the drift check fail. | A1-003, A2-003 |
| P1 | Resolved | Existing macOS applications collided with Homebrew casks instead of being adopted. | The macOS package guide now lists the reviewed collisions and runs Homebrew's adoption flow before the first activation. | A2-005 |
| P1 | Resolved | The Omarchy package hook could not complete reliably because stock `tldr` conflicted with `tealdeer`, optional AUR failures stopped mise, and legacy hosts could lack the dispatcher. | Both platforms now use the stock `tldr` client, so stock Omarchy owns its command without a package conflict. Optional AUR packages run after required runtime setup, and both package hooks guard the Omarchy 4 dispatcher. | A1-004, A3-006, A4-001 |
| P1 | Resolved | The documented Jupyter workflow failed on first use and could report success for a dead server. Custom tokens appeared in process arguments and permissive state files. | The setup now documents environment provisioning. The launcher checks the environment and port, waits for detached startup, secures state, and supplies custom tokens through a mode-0600 token file. | A6-001, A6-002, A6-003, A7-005 |
| P1 | Resolved | Mandatory Git signing made fresh-host commits fail, while the advertised agent Git protections had simple bypasses. | Fresh hosts now default to unsigned commits and have a signing restoration preflight. The agent hooks are documented as advisory, block the reviewed direct bypasses, and test their known limits. | A7-002, A7-003 |
| P1 | Resolved | Interrupted Doom installation could not recover. | The hook now clones and validates in an owned staging directory before renaming the checkout into place. It removes interrupted staging data and reports invalid, dirty, and unexpected-origin checkouts separately. | A6-004 |
| P1 | Resolved | Omarchy installed `ollama-cuda` on every machine without a hardware or model policy. | The shared manifest no longer installs Ollama. Its hardware package, service, and model are documented as per-machine choices. The guide also hands Tailscale and Dropbox to their interactive service installers and lists readiness checks. | A3-004, A7-004 |
| P1 | Resolved | Linux remote commands missed most of the managed environment while bash remained the login shell. | The Omarchy cold-start procedure now switches the login shell to zsh, requires a new login, and verifies the environment through a remote SSH command. | A5-001 |
| P1 | Resolved | Managed terminal key behavior was inconsistent. macOS zsh switched to Emacs mode, and Omarchy Ghostty lost Shift+Enter encodings. | zsh now selects vi mode with a short escape timeout. Ghostty carries both CSI-u Shift+Enter bindings. | A3-001, A5M-002, A5-009, A5-010 |

## `.chezmoiremove` necessity audit

This audit covers all 45 former removal targets. A guarded migration deletes
only a regular file whose SHA-256 matches an audited legacy version. It
warns and preserves every other file. Dropped rules leave any existing targets
untouched.

The audit host still has three listed targets. Its old Git and mise files match
audited versions and can be removed. Its Claude symlink belongs to Claude's
installer, so the new policy preserves it; mise already takes precedence on
`PATH`.

| Target | Necessity finding | Disposition |
| --- | --- | --- |
| `.config/lazygit/config.yaml` | The managed file moved to `config.yml`; lazygit ignores the old name. | Drop rule. |
| `.config/omarchy/extensions/menu.sh` | Omarchy 4 replaced this path, and the repo never managed its contents. | Drop rule. |
| `.config/mise/config.toml` | This path has higher precedence than the managed `conf.d` file and can override tool versions. | Guarded migration. |
| `.local/bin/claude` | Mise shims and activated installs precede `.local/bin`; this may be an official installer symlink. | Drop rule. |
| `.local/bin/codex` | Mise shims and activated installs precede `.local/bin`. | Drop rule. |
| `.local/bin/gemini` | Mise shims and activated installs precede `.local/bin`. | Drop rule. |
| `.local/bin/gh` | Mise shims and activated installs precede `.local/bin`. | Drop rule. |
| `.local/bin/opencode` | Mise shims and activated installs precede `.local/bin`. | Drop rule. |
| `.local/bin/pi` | Mise shims and activated installs precede `.local/bin`. | Drop rule. |
| `.bash-preexec.sh` | The managed startup files no longer source the vendored copy. | Drop rule. |
| `.aerospace.toml` | AeroSpace reports an ambiguity when this file and the managed XDG file both exist. | Guarded migration. |
| `.gitconfig` | Git reads this after the managed XDG file, so values here can override managed settings. | Guarded migration. |
| `.hyprspace.toml` | HyprSpace is no longer installed or referenced. | Drop rule. |
| `.icas.toml` | The personal configuration does not install or invoke icas. | Drop rule. |
| `.Brewfile` | nix-darwin generates its own Brewfile and never reads this path. | Drop rule. |
| `.local/bin/check-homebrew` | No managed command invokes the retired helper. | Drop rule. |
| `.local/bin/dump-homebrew` | No managed command invokes the retired helper. | Drop rule. |
| `.local/bin/sync-homebrew` | No managed command invokes the retired helper. | Drop rule. |
| `.local/bin/sync-uv` | Mise replaced this helper and no managed command invokes it. | Drop rule. |
| `.local/bin/sync-bun` | Mise replaced this helper and no managed command invokes it. | Drop rule. |
| `.config/shell/00_init.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/05_prefer_zsh.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/05_zsh_completions.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/10_bash_init.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/15_host_env.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/25_nvim.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/30_env.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/30_interactive.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/35_keychain.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/40_python.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/45_omarchy.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/99_finish.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/base.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/interactive.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/lib.sh` | Flat rendered startup files replaced the shell fragment loader. | Drop rule. |
| `.config/shell/personal` | The old directory is no longer sourced; recursive deletion would risk local files. | Drop rule. |
| `.config/shell/work` | The old directory is no longer sourced; recursive deletion would risk local files. | Drop rule. |
| `.config/themes` | Managed applications now name their themes directly; recursive deletion would risk local themes. | Drop rule. |
| `.config/btop/themes/current.theme` | btop now names its managed Gruvbox theme directly. | Drop rule. |
| `.config/omarchy/hooks/theme-set` | Omarchy 4 uses `theme-set.d`; this path can belong to a user or later release. | Drop rule. |
| `.config/atuin/themes/rose-pine-moon.toml` | Atuin selects the managed Gruvbox theme. | Drop rule. |
| `.config/bat/themes/rose-pine-moon.tmTheme` | Bat selects the managed Gruvbox theme. | Drop rule. |
| `.config/btop/themes/rose-pine-moon.theme` | btop selects the managed Gruvbox theme. | Drop rule. |
| `.config/zellij/themes/rose-pine-moon.kdl` | Zellij selects Gruvbox rather than this retired theme. | Drop rule. |
| `.vim/pack/plugins/start/rose-pine` | Vim selects Gruvbox; recursively deleting a plugin directory would risk unrelated changes. | Drop rule. |

## P2 stabilization work

- Make runtime ownership deterministic. Add `macos-arm64` mise lock entries,
  stop mise from shadowing Omarchy-owned `herdr`, `usage`, and `tree-sitter`,
  remove global macOS GCC unless required, report PATH drift, and correct the
  `mise self-update` instructions.
- Normalize shell behavior. Own zsh history explicitly, fix locale validation,
  honor inherited Jupyter variables, make `extras.sh` available where
  documented, preserve an existing SSH agent, and disable nix-darwin's second
  global `compinit`.
- Resolve desktop ownership. Decide whether chezmoi or Omarchy owns monitor
  scaling, gate display-specific settings by host, configure AeroSpace startup
  and Accessibility onboarding, and move its global shortcuts away from
  terminal and editor keys.
- Make application installs reproducible. Build micromamba environments without
  deleting the working copy first, add environment locks, decide whether to
  track Neovim's lock, avoid the headless Lazy bootstrap hang, and move
  OpenCode's theme to `tui.json`.
- Disable greedy Homebrew cask upgrades unless the flake is intentionally the
  sole application updater.
- State the supported platform boundary. The current effective targets are
  Apple Silicon macOS and Omarchy x86_64. Decide whether Omarchy 3 remains
  supported.
- Resolve the privacy policy mismatch around historical employer addresses.
  Add practical guidance for protecting `extras.sh` and generated credential
  files.

## P3 maintenance work

### Resolved

- `nix-switch` now quotes a source path containing spaces, and
  `create_direnv_micromamba` quotes the generated environment name.
- The shared path setup adds its man directory once, and the macOS temp-directory
  guard handles `/tmp` and `/private/tmp` with or without a trailing slash.
- Bash completion now uses its default XDG data directory instead of exporting
  the same path after initialization.
- The AeroSpace config no longer carries the deprecated `after-login-command`
  option.
- Non-macOS hosts now exclude the nix-darwin drift hook from the managed script
  set.
- Shell documentation and comments now distinguish remote shell startup from
  cron, launchd, systemd and directly executed Git hooks. They also record the
  nix-darwin `path_helper` behavior and the Bash-only Omarchy helper set.
- The README and cold-start guide now state that `--refresh-externals=never`
  still downloads missing externals and that the Vim archives have no committed
  content checksums.

### Open

- decide whether the Vim external trust policy requires committed archive
  checksums;
- test the remaining hypothesis about unbinding disabled Omarchy defaults.

## Required policy decisions

Implementation depends on owner decisions in these areas:

- whether Omarchy 3, Linux arm64, or Intel macOS are supported;
- whether chezmoi or Omarchy owns runtime monitor scaling;
- whether display-specific Hyprland settings apply globally;
- whether Neovim and micromamba deployments must be reproducible from committed
  locks.
- whether commit-pinned Vim plugin archives also require committed content
  checksums.

## Remaining review gaps

The static review is strong, but the review plan's final validation stage is
not complete:

- No complete stock macOS or Omarchy cold start was run.
- No real `darwin-rebuild switch`, Homebrew cask adoption or cleanup, Omarchy
  package transaction, reboot, or service authentication sequence ran on a
  disposable host.
- First, second, and third apply transcripts are missing.
- macOS application behavior, Docker behavior, Accessibility prompts, and
  findings marked `likely` or `hypothesis` still need dynamic verification.
- The full cold-start tests must run after remediation and again against the
  commit that will land on `main`.

Agent 3's Omarchy verdict covered only the integration workstream. The package
and application reports found independent first-use blockers, so the combined
Omarchy verdict remains blocked.
