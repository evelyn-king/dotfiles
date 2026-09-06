# Omarchy VM cold-start test

Run on 2026-09-06 against commit
`25af7082b6a455f09796adebd78cad76331a8d7c`. Verdict: **blocked**.
The VM installed and booted successfully, but all three dotfiles applies failed
at the same missing micromamba lock metadata. This is a diagnostic run, not a
successful deployment or validation of a future merge commit.

## Environment and evidence

- Official `omarchy-4.0.2.iso`, downloaded from `https://iso.omarchy.org/`.
- SHA-256 matched the published `.iso.sha256` file:
  `2ef8e624aa1bec7e277e28056b8535a6c9373ba48d7ede3f1a01cb6d2373cfb8`.
- Installed package version from `omarchy version`: `4.0.2-1`.
- QEMU/KVM, UEFI, VirtIO graphics/network/storage, 8 vCPUs, 16 GiB RAM,
  120 GiB sparse disk. Unknown hostname `omarchy-cold-vm`.
- Omarchy's unattended installer used a generated test account, no disk
  encryption, and a dedicated SSH public key. SSH was forwarded only on host
  localhost port 2227. No personal service credentials were imported.
- The public default branch differed from the reviewed branch and rejected
  the unknown hostname during init. A Git bundle supplied the exact reviewed
  commit before successful initialization. The default-branch failure is not
  attributed to the reviewed commit.
- The host-local artifacts live under `~/VMs/omarchy-cold-start/`. The `logs/`
  directory contains command transcripts, exit codes, and elapsed times.
  The powered-off disk has `stock-4.0.2` and `failed-25af708` snapshots, with
  matching saved UEFI variables. Start the preserved failed state with
  `bash ~/VMs/omarchy-cold-start/start.sh`. The VM is shut down.

## Results

| Check | Result | Evidence in `logs/` |
| --- | --- | --- |
| Stock install and Hyprland login | Passed; stock Hyprland reported no config errors | `stock-baseline.log`, `stock-desktop.log`, `reviewed-commit-init.log` |
| Documented chezmoi bootstrap | Failed; stock package indexes were absent | `bootstrap-chezmoi.log` |
| Bootstrap recovery | `omarchy update system-pkgs` populated indexes and completed a full upgrade; chezmoi then installed | `bootstrap-package-update.log` |
| Init and first dry run on reviewed commit | Passed; missing pinned externals downloaded | `reviewed-commit-init.log`, `first-dry-run.log` |
| First apply | Required pacman transaction completed; Doom skipped because Emacs was initially absent; mise failed; later hooks were not reached | `first-apply.log` |
| Login shell and reboot | zsh selected; guest rebooted and logged into Hyprland | `reboot-after-first-apply.log`, `shell-and-desktop-checks.log` |
| Second apply | Doom installed successfully; mise failed again | `second-apply.log` |
| Third apply | Failed again at micromamba; did not converge to a successful quiet apply | `third-apply.log` |
| Managed file convergence | Final file diff empty; script work still pending | `final-file-state.log` |
| Non-interactive SSH environment | Managed micromamba root, locale, and PATH present without a PTY | `remote-shell-no-tty.log` |
| zsh key mode | `viins` and `KEYTIMEOUT=2` | `shell-and-desktop-checks.log` |
| Hyprland after apply and reboot | No config errors; unknown-host monitor configuration worked | `shell-and-desktop-checks.log`, `final-file-state.log` |
| A3-010, disabled preinstalled bindings | Passed; no errors with `preinstalls-removed` present, or after restoring its absence | `disabled-bindings.log` |
| Ghostty configuration | Validation passed | `ghostty-launch.log` |
| Ghostty window | Virtual GPU failed OpenGL requirement; software rendering opened a mapped Wayland window | `ghostty-launch.log`, `ghostty-software-rendering.log` |
| Neovim first use | Headless Lazy sync exited successfully; no startup error detected in transcript | `neovim-first-use.log` |

## Findings

### VM-001: bootstrap requires package indexes

The ISO did not include synchronized pacman databases. The runbook's
`omarchy pkg add chezmoi` failed with `target not found: chezmoi`.
Running `omarchy update system-pkgs` before that command recovered the bootstrap.
The cold-start guide needs this prerequisite. A full package upgrade keeps the
installed packages consistent with the newly downloaded indexes.

### VM-002: micromamba cannot install in locked mode

The `tools.micromamba` entry in `dot_config/mise/mise.lock` contains a version
and backend, but no platform URLs or checksums. A fresh `mise install --locked`
fails with `No lockfile URL found for micromamba@2.9.0-0 on platform linux-x64`.
All three applies exited 1 at this hook. The pinned upstream release has Linux
and macOS assets, so the missing metadata needs repair and a fresh-install
verification. Existing host installations can conceal this failure.

### VM-003: stock mise configuration overrides the repo

The migration guard preserves the stock `~/.config/mise/config.toml` because
its hash is not in the audited list. Its Node pin and Codex `latest` declaration
then take precedence over the managed declarations. The runtime check selected
Node `26.8.1` and Codex `0.153.4`, while the reviewed lock installed `26.8.0` and
`0.153.2`. The guard correctly avoids deleting unknown user content, but a fresh
stock installation still needs a reviewed ownership handoff.

### VM-004: automatic Vulkan provider selection installs NVIDIA libraries

Installing Zed pulled in the `vulkan-driver` dependency. With no provider
installed in the stock guest, the non-interactive pacman transaction selected
its first provider, `nvidia-utils`, despite the guest using VirtIO graphics.
No Hyprland config error resulted, but this is not a suitable hardware policy.
Review provider selection before treating package installation as hardware-safe.

### VM limitation: Ghostty needs newer OpenGL

The virtual GPU exposed OpenGL 4.2; Ghostty requires 4.3 and could not initialize
a terminal surface. Launching it with `LIBGL_ALWAYS_SOFTWARE=1` produced a mapped
Wayland window. This override was supplied only to the test process and was not
added to the repository or guest configuration. Hardware acceleration and
physical display behavior remain untested.

## Remaining work

Repair the deployment blockers, then restore the stock snapshot and rerun the
complete procedure. The run must also be repeated against the commit that lands
on `main`. Optional AUR hooks and later trust/drift hooks were not reached, so
this run does not validate them. Service authentication, interrupted package
installation recovery, refresh/scaling recovery, terminal key encodings, full
application smoke tests, and Jupyter provisioning remain open. Tailscale,
Dropbox, and Docker were inactive when inspected; their intended setup and
first-use behavior have not been exercised. Physical monitor profiles require
matching hardware.
