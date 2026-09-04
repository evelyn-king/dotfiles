# Deployment topology

Reference material behind the cold-start runbooks: which targets chezmoi
selects on each host, what order the hooks run in, and which setup steps no
script can perform.

Verified against the working tree at commit `8fcb649`. Script order came from
`chezmoi managed --include=scripts`, not from reading filenames.

## Target-selection matrix

Architecture does not affect target selection. The only inputs are
`.chezmoi.os` and the four Omarchy signals in
`.chezmoitemplates/omarchy-detect.tmpl`. Hostname changes the contents of
`~/.config/hypr/monitors.lua`, never whether chezmoi manages a file.

| Scenario | Omarchy detected | Extra managed targets | Ignored |
| --- | --- | --- | --- |
| Apple Silicon macOS | no | `.config/aerospace/aerospace.toml` | `.config/hypr/**`, `.config/superfile/**`, `install-omarchy-packages.sh` |
| Omarchy 4 | yes, via `ID=omarchy` or `/usr/share/omarchy` | four Hypr files, `.config/superfile/**` | `.config/aerospace` |
| Legacy Omarchy 3 | yes, via `~/.local/share/omarchy` | same as Omarchy 4 | `.config/aerospace` |
| Dev-linked Omarchy | yes, when `$OMARCHY_PATH/default` exists | same as Omarchy 4 | `.config/aerospace` |
| Generic Linux | no | `.config/superfile/**` | `.config/aerospace`, `.config/hypr/**`, `install-omarchy-packages.sh` |
| Unknown Omarchy hostname | yes, via any signal | same as Omarchy 4; `monitors.lua` falls back to the default output and automatic scale | `.config/aerospace` |

Omarchy 3 and generic Linux are not supported deployment targets. They are
listed because the templates still select coherently on them.

A stale `OMARCHY_PATH` no longer counts as Omarchy on its own. The template
requires the `default` directory every Omarchy tree carries, so a variable left
over from a deleted checkout cannot make a plain Linux host run
`omarchy pkg add`.

## Hook execution order

chezmoi orders scripts by target name, after stripping the `run_`, `before_`,
`after_` and `onchange_` attributes. The source filenames therefore do not read
in execution order; `zz-` is the prefix that forces the AUR hook last.

| Order | Target | Phase | Runs when |
| --- | --- | --- | --- |
| 1 | `10-migrate-retired-configs.sh` | before | every apply, every platform |
| 2 | `darwin-rebuild.sh` | after | macOS only; reports drift, never activates |
| 3 | `install-doom-emacs.sh` | after, onchange | when Emacs is present |
| 4 | `install-omarchy-packages.sh` | after | Omarchy only; ignored elsewhere |
| 5 | `mise-install.sh` | after, onchange | when mise is present |
| 6 | `tool-drift.sh` | after | every platform; reports only |
| 7 | `trust-local-projects-mise.sh` | after, onchange | when mise is present |
| 8 | `zz-install-omarchy-aur-packages.sh` | after | Omarchy only; guarded internally |

Entries 4 and 8 are both Omarchy-only but use different mechanisms. Entry 4 is
excluded by `.chezmoiignore.tmpl` on non-Omarchy hosts. Entry 8 is always a
managed script and renders to `exit 0` instead. The effect is the same; a
non-Omarchy apply just runs one extra no-op script.

Entry 8 deliberately sorts after entries 4 through 7 so that a failing optional
AUR package cannot stop required runtime setup.

### First-apply timeline, Apple Silicon macOS

1. Install the prerequisites by hand: Command Line Tools, Determinate Nix,
   Homebrew, chezmoi. See [cold-start.md](cold-start.md).
2. **First apply.** Writes normal targets and fetches the six Vim externals.
   Doom, mise install and mise trust all skip, because nix-darwin has not
   supplied Emacs or mise yet. The darwin drift hook reports no current
   generation and prints the first-activation command.
3. **First nix-darwin activation**, run by hand with `nix run` because
   `darwin-rebuild` is not yet on `PATH`. Installs 40 casks, seven App Store
   applications and the Nix package set, and removes the bootstrap Homebrew
   `chezmoi`.
4. Reboot, so the system generation, applications and fonts are present at
   login.
5. **Second apply.** Emacs and mise now resolve, which changes both
   `run_onchange` hashes, so Doom installs its checkout and mise installs the
   locked tool set.
6. **Third apply.** No file changes. The drift and tool-drift hooks still run
   and should print nothing.

### First-apply timeline, Omarchy 4

1. Confirm the Omarchy 4 dispatcher and add chezmoi. Stock Omarchy supplies
   neither this repo nor, reliably, mise.
2. **First apply.** Writes normal targets and fetches externals. Doom skips
   because Emacs is absent. The package hook then restores the declared pacman
   packages, including Emacs, bun and uv. mise installs the locked tool set, trust runs,
   and the 2 optional AUR packages run last.
3. `chsh` to zsh and log out fully, so non-interactive SSH commands get the
   managed environment.
4. **Second apply.** Emacs now resolves, so Doom installs.
5. **Third apply.** No file changes, but not command-free: both package hooks
   still call the Omarchy helpers and both reporting hooks still run.

## Manual-state inventory

Nothing in this table can be automated from the repository. "Documented" means
a runbook covers it; "undocumented" means the step is real but written down
nowhere.

| Item | Platform | Classification | Where |
| --- | --- | --- | --- |
| Command Line Tools, Nix, Homebrew, chezmoi | macOS | documented | [cold-start.md](cold-start.md) |
| Omarchy dispatcher and chezmoi | Omarchy | documented | [cold-start.md](cold-start.md) |
| First nix-darwin activation | macOS | documented | [cold-start.md](cold-start.md) |
| Homebrew cask adoption | macOS | documented | [package-lists/macos.md](package-lists/macos.md) |
| App Store sign-in for `masApps` | macOS | documented | [package-lists/macos.md](package-lists/macos.md) |
| Xcode license acceptance | macOS | documented | [package-lists/macos.md](package-lists/macos.md) |
| Accessibility approval for AeroSpace | macOS | documented | [cold-start.md](cold-start.md) |
| Login shell change to zsh | Omarchy | documented | [cold-start.md](cold-start.md) |
| SSH key generation and registration | both | documented | [cold-start.md](cold-start.md) |
| GPG secret key, trust and pinentry | both | documented | [cold-start.md](cold-start.md) |
| Enabling commit signing | both | documented | [cold-start.md](cold-start.md) |
| Tailscale and Dropbox sign-in | Omarchy | documented | [package-lists/omarchy-linux.md](package-lists/omarchy-linux.md) |
| Ollama package, service and model | Omarchy | documented | [package-lists/omarchy-linux.md](package-lists/omarchy-linux.md) |
| Micromamba environments and Jupyter | both | documented | `README.md` |
| Container runtime initialization | macOS | **undocumented** | Rancher Desktop is a declared cask; its first run, VM creation and interaction with `DOCKER_DEFAULT_PLATFORM` are written down nowhere |
| GitHub, Google Cloud, agent CLI, Atuin, Bitwarden, 1Password sign-in | both | **undocumented** | Covered only by one sentence about launching applications |
| Host-specific monitor and input configuration | Omarchy | **undocumented** | `monitors.lua` is seeded once; named profiles exist only for known hosts |
| Reboots and application restarts | both | documented | [cold-start.md](cold-start.md) |
