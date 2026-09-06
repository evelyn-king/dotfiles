# Deployment review summary

## Review state

The nine agent reports contain 93 findings, with substantial overlap. This
document combines them into one remediation queue.

The reports reviewed source commits `30923db` and `abb2e56`. The latter added
only review documents. The remediation table below records changes made after
the review.

This document was last reconciled against the working tree at commit `fd3a77d`.
Re-check the macOS cask and App Store rows after any change to
`nix/flake.nix`; commits `3a6fed4`, `2f8d0c0` and `fd3a77d` changed the package
set after the first version of this summary was written, and one of them
reversed a resolution recorded here.

All four original P0 findings and all ten original P1 findings are resolved.
The [2026-09-06 Omarchy VM run](deployment-review-omarchy-vm.md) found new
bootstrap and runtime blockers in commit `25af708`; these remain open.

The files-only chezmoi target set did converge in disposable homes. The main
failures sit at removal, package installation, system activation, and first-use
boundaries.

## Platform verdicts

| Platform | Verdict | Basis |
| --- | --- | --- |
| Apple Silicon macOS | `blocked` | No known unresolved defect. Blocked only because the plan's dynamic stage never ran: no stock cold start, no real `darwin-rebuild switch`, no cask adoption or cleanup on a disposable host. |
| Omarchy 4 x86_64 | `blocked` | A stock Omarchy 4.0.2 VM was exercised. Bootstrap needed package indexes, and all three applies failed at missing micromamba lock metadata. See the [VM report](deployment-review-omarchy-vm.md) for runtime ownership findings and remaining checks. |

The macOS verdict reflects missing dynamic evidence. Omarchy now has confirmed
cold-start failures as well as incomplete checks. Neither platform can reach
`ready with documented manual steps` until its full cold-start procedure passes.

Converting either verdict requires the work in
[Remaining review gaps](#remaining-review-gaps), and the tests must run against
the commit that lands on `main`.

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
| P2 | Resolved | The privacy rule conflicted with employer addresses retained in commit history, and local credential files lacked protection guidance. | The rule now applies to the current tree and new commits while acknowledging retained history. The local-secret procedure covers credential stores, private modes, atomic writes, backups, and commit checks. | A7-006, A7-007 |
| P2 | Resolved | Supported architectures and Omarchy versions were not defined. | The supported targets are now Apple Silicon macOS and Omarchy 4 on x86_64 Linux. Omarchy 3, Linux arm64 and Intel macOS are explicitly unsupported. | A3-006, A4-003, A4M-010 |
| P2 | Resolved | Greedy Homebrew cask upgrades conflicted with application self-updaters. | Casks are non-greedy. 37 of the 40 declared casks self-update and now own their own versions; `upgrade = true` still covers the three that do not. `bartender` and `raindropio` opt back in because they rotted under their own updaters. Superseded the earlier "Homebrew is authoritative for every cask" resolution in commit `2f8d0c0`. | A2-010, A4M-011 |
| P2 | Resolved | macOS mise installs resolved live versions without checksums or a reviewable record. | The shared lock now covers `linux-x64` and `macos-arm64`. Both install hooks and `mup` use the committed lock. | A4M-005 |
| P2 | Accepted | Mise shadowed three Omarchy-owned commands and recreated a stale Herdr client that Omarchy removes. | The shadowing is now intentional, superseding the earlier "let the stock packages own them" resolution. `herdr`, `usage` and `tree-sitter-cli` are declared once for both platforms, and their shims outrank `/usr/bin`, because one pinned version per tool across machines is worth more here than the Arch versions, which trailed on `usage` and `tree-sitter`. The stale-Herdr protocol risk this finding raised is unchanged and is documented at the declaration. | A4-002 |
| P2 | Resolved | Global macOS GCC replaced the Xcode Command Line Tools compiler and linker commands. | The flake no longer installs GCC globally. Project-specific development shells can add it when a build requires GCC. | A4M-006 |
| P2 | Resolved | macOS had no warning when bootstrap or manually installed commands shadowed Nix packages, and neither platform reported stale mise installs. | The cross-platform tool-drift hook reports duplicate manual installs and prunable mise versions. On macOS it also reports commands shadowing the active Nix generation. | A4M-008 |
| P2 | Resolved | The documented `mise self-update` command could not update package-managed mise on either platform. | The update instructions now use the owning package manager: Nix flake activation on macOS and the normal Omarchy update on Linux. | A2-011, A4-004, A4M-009 |
| P2 | Resolved | zsh history was absent on Linux and inherited small, platform-specific defaults on macOS. | zsh now keeps 100,000 entries under `$XDG_STATE_HOME` with explicit append and duplicate handling. | A5-002, A5M-003 |
| P2 | Resolved | Linux ignored the system locale in clean sessions, while macOS accepted unsupported inherited locale names. | Shell startup validates inherited locales against the host, then reads `/etc/locale.conf` on Linux or `AppleLocale` on macOS before portable fallbacks. | A5-003, A5M-004 |
| P2 | Resolved | Shell startup overwrote inherited Jupyter bind, environment, and port variables. | Jupyter variables now use defaults only when the parent did not provide a value. | A5-005 |
| P2 | Resolved | `extras.sh` overrides were documented for remote Jupyter use but loaded only by interactive shells. | The local override file now runs after shared defaults in every shell that reads a managed startup file. | A5-004 |
| P2 | Resolved | Keychain replaced valid local SSH agents, including macOS's launchd agent, because only OpenSSH forwarding sockets were recognized. | Interactive startup keeps any inherited agent that responds to `ssh-add -l` and starts keychain only as a fallback. | A5-014, A5M-005 |
| P2 | Resolved | nix-darwin and the managed zsh configuration both ran `compinit` with different `fpath` values. | nix-darwin's global completion initialization is disabled, leaving the managed `~/.zshrc` as the single owner. | A5M-001 |
| P2 | Resolved | AeroSpace was installed but did not start automatically, and its required Accessibility approval was easy to miss. | AeroSpace now starts at login after initial launch. The macOS cold-start guide names the approval path, restart, and verification command. | A2-008 |
| P2 | Resolved | AeroSpace captured bare Control shortcuts before terminal shells, Vim, or Neovim could receive them. | Main-mode shortcuts now use a dedicated `Ctrl-Alt` prefix, and the keybinding guide records the full map. | A2-007 |
| P2 | Resolved | The `gimli` monitor profile gave GTK a fractional scale that GTK does not support. | The profile keeps Hyprland at `1.6667` and gives GTK its nearest integer scale, `2`. | A3-002 |
| P2 | Resolved | Omarchy's monitor-scaling control edited a chezmoi-managed file, so the next apply discarded the selected scale. | Chezmoi now seeds `monitors.lua` only when it is missing. Omarchy owns later changes. | A3-003 |
| P2 | Resolved | A golden-ratio single-window limit applied to every display, regardless of its dimensions. | Lua now enables the global limit only when an enabled display is wider than the golden ratio. It reevaluates after config reloads and monitor changes. | A3-007 |
| P2 | Accepted | Neovim does not share a plugin lock across hosts. | Plugin revisions intentionally float. lazy.nvim owns a machine-local `lazy-lock.json`, which remains ignored. | A6-007 |
| P2 | Accepted | Micromamba environment specifications do not pin versions or use lockfiles. | Environments intentionally resolve current packages from the managed YAML files during each rebuild. | A6-006 |
| P2 | Resolved | Refreshing a micromamba environment deleted the working environment and kernel before solving or installing its replacement. | The installer now builds and smoke-tests a staging environment first. It retains rollback copies until the final environment and staged kernel are ready. | A6-005 |
| P2 | Resolved | A failed lazy.nvim clone waited forever for a key during headless Neovim startup. | The bootstrap waits for acknowledgement only when a UI is attached and exits immediately with failure in headless mode. | A6-008 |
| P2 | Resolved | OpenCode migrated the managed theme out of `opencode.json`, leaving permanent chezmoi drift. | The runtime config no longer contains TUI settings. A managed `tui.json` owns the system theme through the current TUI schema. | A6-009 |

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

No P2 stabilization work remains.

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
  still downloads missing externals. The Vim archive policy accepts
  commit-pinned GitHub URLs over HTTPS without committed content checksums.

Found while reconciling this document against commit `fd3a77d`, after the
package-set commits landed:

- The flake's cask comment claimed 43 of 47 casks self-update and named
  `1password-cli`, which the flake no longer declares. Counts are now 37 of 40,
  verified with `brew info --json=v2`, and the three non-self-updating casks are
  named correctly. A recount command sits next to them.
- The greedy-cask note named `notion-calendar`, which is not declared. Only
  `bartender` and `raindropio` opt in.
- The macOS package guide claimed Homebrew is authoritative for every cask. It
  now describes the non-greedy policy and the two opt-ins.
- The cask adoption procedure listed nine applications, chosen before 30 more
  casks were declared. It now derives the list from the flake with `nix eval`,
  so it cannot go stale again, and shows how to preview the collisions.
- `homebrew.masApps` was undocumented. The macOS guide now carries an ownership
  row, the seven applications and their ids, the App Store sign-in prerequisite,
  Xcode's size and its separation from the Command Line Tools, and the fact that
  removing an entry does not uninstall the application.

### Dynamically verified

- A3-010 passed in the Omarchy 4.0.2 VM: temporarily disabling preinstalled
  bindings and reloading produced no config errors. Restoring the defaults
  was also clean. See the [VM report](deployment-review-omarchy-vm.md).

## Required policy decisions

No policy decisions remain.

## Untraced findings

The nine reports contain 93 findings. This document cites 66 by ID. Of the 27
uncited, about 15 are covered by the P3 prose above without their IDs. The
following 12 appear nowhere in this document in any form. Most are fixed or
moot in the current tree, but the summary cannot show that, so record a
disposition for each:

| ID | Severity | Current tree state |
| --- | --- | --- |
| A1-006 | low | Covered by the P3 externals note. Needs an ID. |
| A2-012 | low | First activation downloads roughly 1.2 GiB. Not in the cold-start guide. |
| A2-014 | low | `darwinConfigurations` defines only `macbook`. The guide names it explicitly, so the mismatch is documented rather than fixed. |
| A3-005 | medium | Addressed. The `OMARCHY_PATH` probe requires a non-directory `default/bash/env-bootstrap` entry. Unrelated existing paths fall through to the OS and standard-installation signals. |
| A3-008 | low | Addressed. `dot_bashrc.tmpl` re-sources Omarchy's completions selectively and documents the replacement. |
| A3-009 | low | Addressed. The [Hyprland refresh guide](package-lists/omarchy-linux.md#refreshing-hyprland-config) documents overwritten files, retained backups, toggle resets, and recovery, including the seed-only monitor exception. |
| A4M-007 | low | Addressed. The mise hook installs `bun` and `uv` on Omarchy and fails with a clear message elsewhere. Nix supplies all three on macOS. |
| A5-006 | low | Addressed. `shell-env.sh` sources Omarchy's `env-bootstrap`. |
| A5-013 | low | Addressed. `dot_direnvrc` checks `DIRENV_SHELL` then the shell version variables. |
| A5-016 | low | Moot once A5-001 fixed the login shell. |
| A5-017 | low | Kept, deliberately. The file states the setting explicitly instead of inheriting it, and it applies on macOS and generic Linux where Omarchy's installer never runs. Redundant only on Omarchy. |
| A5M-008 | low | Addressed. `DOCKER_DEFAULT_PLATFORM` is inside a Darwin guard with its rationale. |
| A5M-009 | low | Addressed. The cold-start guide tells the user not to append `brew shellenv` to `~/.zprofile`. |

## Synthesis deliverables

The plan's final synthesis asks for nine artifacts. Eight now exist:

- **Readiness verdicts** are above.
- **Target-selection matrix**, **first-apply hook timeline** and the
  **manual-state inventory** are in
  [deployment-topology.md](deployment-topology.md), rebuilt against the current
  tree rather than copied from the agent 1 report. The hook order there came
  from `chezmoi managed --include=scripts`; the report's order predates the
  merge of the two drift hooks and is wrong.
- **Cold-start runbooks**, the **package ownership matrix** and the **patch
  queue** were already covered by `docs/cold-start.md`, `docs/package-lists/`
  and the remediation table above.

The ninth, **first, second and third apply transcripts**, requires the dynamic
stage below.

Three rows of the manual-state inventory are classified as undocumented manual
work rather than written up: container runtime initialization, per-service
sign-in, and host-specific monitor and input configuration.

## Remaining review gaps

The static review is strong, but the review plan's final validation stage is
not complete:

- No complete stock macOS cold start was run. The Omarchy VM cold start ran
  but failed; fix the [reported blockers](deployment-review-omarchy-vm.md) and
  repeat it from the stock snapshot.
- No real `darwin-rebuild switch`, Homebrew cask adoption or cleanup ran.
  Omarchy package installation and reboot ran, but service authentication and
  the remaining VM checks are still unverified.
- Omarchy first, second, and third apply transcripts now exist, all showing
  failure at the mise hook. macOS transcripts are still missing.
- macOS application behavior, Docker behavior, Accessibility prompts, and
  findings marked `likely` or `hypothesis` still need dynamic verification.
- The full cold-start tests must run after remediation and again against the
  commit that will land on `main`.

These are the only items standing between the current tree and a
`ready with documented manual steps` verdict on either platform.
