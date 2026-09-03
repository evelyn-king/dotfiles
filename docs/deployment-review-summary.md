# Deployment review summary

## Review state

The nine agent reports contain 93 findings, with substantial overlap. This
document combines them into one remediation queue.

The reports reviewed source commits `30923db` and `abb2e56`. The latter added
only review documents. Current commit `4e77a95` adds the macOS reports and no
source configuration changes, so the findings still apply.

Both target platforms are blocked for a fresh deployment:

- macOS cannot activate the checked-in nix-darwin configuration. The username
  is wrong and the unfree Terraform package prevents evaluation.
- Omarchy cannot complete an unattended first apply. Persistent removal rules
  risk user data, and the stock `tldr` package conflicts with the requested
  `tealdeer` package.

The files-only chezmoi target set did converge in disposable homes. The main
failures sit at removal, package installation, system activation, and first-use
boundaries.

## Remediation priorities

`P0` means the issue must be resolved before another live apply or system
activation. It does not replace the severity recorded in the source reports.

| Priority | Status | Consolidated finding | Required resolution | Review IDs |
| --- | --- | --- | --- | --- |
| P0 | Open | `.chezmoiremove` can recursively delete unrelated or newly recreated user data. | Remove expired entries. Replace necessary migrations with exact content or provenance checks. | A1-001, A7-001, A3-012 |
| P0 | Resolved | The macOS flake hardcoded user `evelyn`, which did not match the owner's account. | `system.primaryUser` is now set for the `macbook` host as `evelynking`. | A2-001, A4M-003 |
| P0 | Resolved | `terraform` was unfree, but the flake had no license exception, so the configuration could not evaluate. | Terraform has been removed from the macOS system package set. | A2-002, A4M-001 |
| P0 | Open | Homebrew activation uses `--force-cleanup`, which can remove every undeclared formula, cask, and tap. | Default to `cleanup = "check"` or `"none"` until full Homebrew ownership is an explicit policy. | A2-004, A4M-004 |
| P1 | Open | Neither platform has a complete cold-start procedure. | Document installation of chezmoi, Nix, Homebrew, and Omarchy prerequisites, activation order, login or reboot, repeated applies, and final verification. | A1-002, A1-005, A2-006, A3-011, A4M-002 |
| P1 | Open | The nix-darwin drift hook hides evaluation errors and fails before the first generation exists. | Handle the no-generation state, preserve evaluation errors, and distinguish failure from convergence. | A1-003, A2-003 |
| P1 | Open | Existing macOS applications collide with Homebrew casks instead of being adopted. | Add a documented or scripted cask-adoption preflight before activation. | A2-005 |
| P1 | Open | The Omarchy package hook cannot complete reliably. Stock `tldr` conflicts with `tealdeer`; optional AUR failures stop mise; legacy or partial hosts may lack the `omarchy` dispatcher. | Resolve `tldr` ownership, isolate optional packages, and guard the required CLI. | A1-004, A3-006, A4-001 |
| P1 | Open | The documented Jupyter workflow fails on first use and can report success for a dead server. Custom tokens appear in process arguments and permissive state files. | Create state directories first, provision environments, verify startup and port readiness, use modes 0700 and 0600, and keep tokens out of process arguments. | A6-001, A6-002, A6-003, A7-005 |
| P1 | Open | Mandatory Git signing makes fresh-host commits fail, while the advertised agent Git protections have simple bypasses. | Add signing preflight and restoration instructions. Strengthen and test the command policy or document it as advisory. | A7-002, A7-003 |
| P1 | Open | Interrupted Doom installation cannot recover. | Clone into a temporary sibling, validate it, then rename it atomically. Diagnose invalid checkouts separately from dirty ones. | A6-004 |
| P1 | Open | Omarchy installs Tailscale, Dropbox, and Ollama packages without making the services usable. It installs `ollama-cuda` on non-NVIDIA machines. | Add a post-apply readiness checklist and hardware-aware Ollama ownership. | A3-004, A7-004 |
| P1 | Open | Linux remote commands miss most of the managed environment while bash remains the login shell. | Document and verify switching the login shell to zsh, or provide another SSH environment mechanism and narrow the startup claims. | A5-001 |
| P1 | Open | Managed terminal key behavior is inconsistent. macOS zsh switches to Emacs mode, and Omarchy Ghostty loses Shift+Enter encodings. | Set zsh vi mode explicitly and restore the two CSI-u bindings. | A3-001, A5M-002, A5-009, A5-010 |

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

- whether `.chezmoiremove` retains any long-lived migration rules;
- whether Homebrew owns the entire prefix or only the declared applications;
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
