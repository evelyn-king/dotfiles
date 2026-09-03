# Deployment review summary

## Review state

The nine agent reports contain 93 findings, with substantial overlap. This
document combines them into one remediation queue.

The reports reviewed source commits `30923db` and `abb2e56`. The latter added
only review documents. The remediation table below records changes made after
the review.

All four P0 findings are resolved. A live apply still needs the open P1
cold-start work and final validation. Omarchy also cannot complete an
unattended first apply because the stock `tldr` package conflicts with the
requested `tealdeer` package.

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
| P1 | Open | Neither platform has a complete cold-start procedure. | Document installation of chezmoi, Nix, Homebrew, and Omarchy prerequisites, activation order, login or reboot, repeated applies, and final verification. | A1-002, A1-005, A2-006, A3-011, A4M-002 |
| P1 | Resolved | The nix-darwin drift hook hid evaluation errors and failed before the first generation existed. | The hook now gives the first-activation command when no generation exists. Evaluation errors remain visible and make the drift check fail. | A1-003, A2-003 |
| P1 | Open | Existing macOS applications collide with Homebrew casks instead of being adopted. | Add a documented or scripted cask-adoption preflight before activation. | A2-005 |
| P1 | Partial | The Omarchy package hook cannot complete reliably because stock `tldr` conflicts with `tealdeer`. | Optional AUR packages now run after required runtime setup, and both package hooks guard the Omarchy 4 dispatcher. Choose whether stock `tldr` or `tealdeer` owns the command. | A1-004, A3-006, A4-001 |
| P1 | Resolved | The documented Jupyter workflow failed on first use and could report success for a dead server. Custom tokens appeared in process arguments and permissive state files. | The setup now documents environment provisioning. The launcher checks the environment and port, waits for detached startup, secures state, and supplies custom tokens through a mode-0600 token file. | A6-001, A6-002, A6-003, A7-005 |
| P1 | Open | Mandatory Git signing makes fresh-host commits fail, while the advertised agent Git protections have simple bypasses. | Add signing preflight and restoration instructions. Strengthen and test the command policy or document it as advisory. | A7-002, A7-003 |
| P1 | Resolved | Interrupted Doom installation could not recover. | The hook now clones and validates in an owned staging directory before renaming the checkout into place. It removes interrupted staging data and reports invalid, dirty, and unexpected-origin checkouts separately. | A6-004 |
| P1 | Open | Omarchy installs Tailscale, Dropbox, and Ollama packages without making the services usable. It installs `ollama-cuda` on non-NVIDIA machines. | Add a post-apply readiness checklist and hardware-aware Ollama ownership. | A3-004, A7-004 |
| P1 | Open | Linux remote commands miss most of the managed environment while bash remains the login shell. | Document and verify switching the login shell to zsh, or provide another SSH environment mechanism and narrow the startup claims. | A5-001 |
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

Fix the narrow correctness and documentation issues after deployment is safe:

- quote source and environment names containing spaces;
- make `MANPATH` idempotent and handle trailing slashes in `TMPDIR`;
- remove or reposition the ineffective bash-completion setting;
- remove the deprecated AeroSpace option;
- exclude the macOS drift hook on Linux;
- document cold-cache external downloads and add archive checksums if they are
  part of the trust policy;
- correct the claims about cron, launchd, Git hooks, `path_helper`, and Omarchy
  shell helpers;
- test the remaining hypothesis about unbinding disabled Omarchy defaults.

## Required policy decisions

Implementation depends on owner decisions in these areas:

- whether mandatory Git signing and agent Git hooks are hard requirements or
  advisory controls;
- whether Omarchy 3, Linux arm64, or Intel macOS are supported;
- whether chezmoi or Omarchy owns runtime monitor scaling;
- whether display-specific Hyprland settings apply globally;
- whether Neovim and micromamba deployments must be reproducible from committed
  locks.

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
