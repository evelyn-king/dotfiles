# Deployment readiness

Reviewed 2026-09-06 against `48ad9b1`. Omarchy follow-up on 2026-09-07
covered the lock at `92afe3f`, code fixes through `a78adca`, and the notebook
runbook correction at `08330ca`.
Supported targets are Apple Silicon macOS with account
`evelynking` and flake `macbook`, and Omarchy 4 on x86_64.

**Ready to open a PR into `main`; merge validation remains incomplete.** No
confirmed core installation blocker remains from the earlier reviews. Complete
the candidate checks before merge; test or explicitly accept the migration gap.
Account and hardware checks belong to each host's deployment sign-off.

| Evidence | What it establishes |
| --- | --- |
| macOS VM, `751b2df` | Three applies, activation, reboot, Doom, mise, cask inventory and file convergence passed. An interrupted cask needed repair. App Store apps were excluded, then separately validated by the owner on the host. GUI readiness remains untested. |
| Omarchy 4.0.2 VM, `563cd9b` | Three applies, packages, reboot, SSH environment, editors, Hyprland recovery and monitor-file preservation passed. Ghostty and Zed opened with software rendering. See the follow-up below for current lock and drift-hook coverage. |
| Omarchy follow-up, `a78adca` | Current locked tools installed from stock; incremental fixes, Doom, reboot, SSH environment, file convergence and dry run passed. Drift warnings were accurate; apply became quiet after removing unused stock Node. Notebook and monitor probes passed as detailed below. |
| macOS source review, `48ad9b1` | macOS dry run and file status are empty. Locked Nix evaluation, both platform shell renderings, lock artifact coverage and nine Git-policy tests passed. No live installation or activation ran. |

## Before merge

- Test the candidate commit on both platforms using the [cold-start guide](cold-start.md).
  The mise lock changed after the macOS VM run. The Omarchy follow-up below
  covers the current lock and corrected drift hook. Record the commit, successful
  locked installation, subsequent applies, empty `status` and `diff` with
  `--exclude=scripts`, and the final dry run. Remaining warnings must describe real conflicts or unused
  tools. Select the candidate branch explicitly at init; the default still
  selects the old tree before merge.
- Exercise an existing-Mac migration on a disposable copy. The
  [adoption procedure](package-lists/macos.md#adopt-existing-applications) now
  fixes shell argument splitting but has not passed a real adoption test.
  Homebrew can reject mismatched app versions, and package installers still
  execute. Verify app bundles as well as receipts,
  interrupted-install recovery, and removal of undeclared Homebrew packages.
  Only bootstrap-formula cleanup has VM coverage. The flake owns the entire
  prefix. Resolve preserved legacy Git, mise and AeroSpace configs
  before relying on their replacements; migration warnings do not fail apply.

## Validate on hosts that use these workflows

- Verify AeroSpace Accessibility, login startup, window shortcuts, GUI editor
  subprocess PATH, and terminal Shift+Enter through tmux. On physical Omarchy
  displays, check GPU acceleration, scaling, rotation, docking and the global
  single-window aspect limit. VM window probes do not cover these.
- Initialize Rancher Desktop on the Mac and test container run/build behavior.
  `shell-env.sh` sets `DOCKER_DEFAULT_PLATFORM=linux/amd64`. Confirm the intended
  image and build architecture. The VM could not validate this backend.
- Repeat the notebook checks on macOS hosts that need them. Both environments,
  detached Jupyter through SSH, kernel execution, replacement rollback and
  direnv activation passed on the Omarchy VM. The installer still solves twice;
  these tests do not establish recovery after power loss.
- Complete service/browser sign-in, SSH-agent reuse and GPG/pinentry checks from
  the [runbooks](cold-start.md#ssh-keys). Git signing defaults off.

## Omarchy follow-up

The review found and fixed these issues:

- `42e072a` recognizes the exact stock Node-only mise config. Previously the
  migration preserved it as unknown, leaving its Node selection above the
  managed declaration. Replay checks removed both audited stock variants and
  preserved modified content and symlinks. The VM apply removed the stock file.
- `a78adca` updates the single-window aspect limit on
  [`monitor.layout_changed`](https://wiki.hypr.land/configuring/core/advanced-configuration/events/).
  A runtime change from 1280×800 to 1920×1080 previously left the limit disabled.
  The fix passed resolution, rotation, scaling, virtual monitor attachment and
  removal checks, with no Hyprland config errors. Physical docking and GPU
  checks remain open.
- `08330ca` runs the README kernel-list check through `micromamba run -n jupyter`.
  A fresh SSH shell has no standalone `jupyter` command after provisioning. The
  corrected command listed both registered environments.

`155e1b4` also makes direnv request a Bash micromamba hook unconditionally,
matching [direnv's Bash subprocess](https://direnv.net/#faq). The previous
hook happened to work with the installed micromamba. Activation and unloading
passed for both shell exports and for the real analysis environment from zsh.

The fresh stock Omarchy 4.0.2 VM initialized `155e1b4`, installed the current
mise lock successfully, and received the fixes through `a78adca` during the
review. This was an incremental repair test from a stock snapshot. A separate
cold start at the final commit remains untested. Required and optional packages,
Doom compilation, reboot, the SSH environment, complete locked-tool inventory,
empty file status/diff and the final dry run passed. The drift hook reported
only the unused stock `node@26.8.1`; removing that version through mise made
apply quiet. Stock launchers and locked tools did not produce false warnings.

Both notebook YAMLs built through `install-micromamba-env`. A detached Jupyter
server remained reachable after SSH disconnected. Authenticated API requests
started both registered kernels, which executed code and imported their main
libraries. Separate disposable environments passed injected failures at final
environment creation and kernel publication; the old environment and kernel
returned unchanged and remained usable. These probes do not cover power loss.

An empty inherited SSH agent survived managed zsh startup. Packaged and
mise-managed Herdr both reported 0.8.2. Service sign-in, real SSH forwarding,
GPG/pinentry, and physical display behavior still need host validation.

Evidence is in `~/VMs/omarchy-review-92afe3f/logs/`, with the VM disk and probe
scripts alongside it. No personal account credentials were copied into the VM.

Floating shell-selected mise versions, Neovim plugins, notebook dependencies,
Vim archive trust and advisory agent hooks remain documented policy choices.
Watch the mise Herdr pin after Omarchy updates for client/server incompatibility.
The complete nix-darwin drift state matrix remains untested.

This page replaces the review plan, topology and individual reports. Their
findings and transcript locations remain in Git at `48ad9b1` under
`docs/deployment-review-*.md`. Operational instructions remain in
[cold-start.md](cold-start.md), [package-lists/](package-lists/) and the README.
