# mise tool list

mise installs the same language runtimes and user-level CLI tools on macOS,
Omarchy, and Ubuntu. The plain TOML files in
[`dot_config/mise/conf.d/`](../../dot_config/mise/conf.d/) declare tool versions
under `[tools]`. Read those files for the lists. Ubuntu also has native package
declarations under `[bootstrap.packages]`; those are applied through APT.

The source files must remain plain TOML. Installation and locking read them
directly through `MISE_CONFIG_DIR`, without chezmoi rendering. Chezmoi applies
the shared declarations to every host and the Ubuntu native declaration file
only to Ubuntu.

Most tools carry exact pins. The coding agents, `gh` and `usage` track `latest`
by design, and Rust tracks the stable release channel. On every supported host,
[`dot_config/mise/mise.lock`](../../dot_config/mise/mise.lock) resolves the
declarations to reviewable versions and checksums for `linux-x64` and
`macos-arm64` wherever the backend exposes a fixed artifact. The Rust entry
stays `stable`, and rustup resolves that channel when mise installs or updates
it.

The lock controls the apply hook and `mup` installations. Normal shells read
the applied declarations without that source-tree lock, so a `latest`
declaration can select a newer version already installed on the machine. Removing
a conflicting stock config restores the managed declarations but does not pin
floating tools to the lock at runtime. Check the effective selection with
`mise ls --current` and `mise which <command>` after migration.

## Overlap with Omarchy packages

Omarchy ships its own `herdr`, `usage` and `tree-sitter-cli` packages, so on
Omarchy those commands exist twice. The mise shims lead `/usr/bin` on
`PATH`, so the pinned version is the one that runs. That overlap is chosen
rather than tolerated. Pinning one version per tool across supported hosts is
worth more here than deferring to whatever Arch last shipped, which has trailed
the pinned versions, in `usage`'s case by a major release. Nothing uninstalls
the system copies, so anything invoking them by absolute path still gets the
packaged build.

`herdr` is the one to watch. Omarchy migration `1786273938` removes a
mise-installed `herdr` precisely because a stale client can shadow the packaged
one with an older wire protocol, and this declaration puts it back. If an
Omarchy update ever moves the herdr protocol, either bump the pin here in the
same session or drop the `herdr` line and let the package own it again.

Pixi is managed only by mise on every supported host. Do not add it to pacman or Nix
package lists. `~/.pixi/bin` stays on PATH for tools installed through Pixi
itself.

## Conflicting mise configs

`~/.config/mise/config.toml` outranks the managed `conf.d` file, and so does a
stray `conf.d/20-macos.toml`. `run_before_10-migrate-retired-configs.sh` removes
either one when its contents match an audited version, and preserves and warns
about anything else. The audited versions include the stock configuration
captured during the Omarchy VM cold-start review.
If it warns, inspect the preserved file and move any declarations or settings
you still want into `10-dotfiles.toml`, then remove the conflicting file. A
different stock release still needs review; the migration never deletes a file
based on its location alone.

## Installation and updates

`run_onchange_after_mise-install.sh.tmpl` hashes every managed `conf.d/*.toml`
filename and body, plus the shared lock. Adding, editing, or removing a
configuration file retriggers installation. It invokes only the tools phase of
`mise bootstrap --locked`; chezmoi owns dotfiles and shell activation.

The npm and pipx installers are themselves pinned mise tools. Mise installs
those dependencies before their consumers, including on a fresh host with no
system copies. The terminal tool declarations also replace explicit native
package declarations. Existing Omarchy copies may remain as distribution
packages; mise's PATH takes precedence. On macOS, apply the tool installation
before activating the Nix generation that removes the old native declarations.

After editing a declaration, refresh the lock without bumping unrelated tools:

```bash
MISE_CONFIG_DIR="$(chezmoi source-path)/dot_config/mise" \
  mise --cd / lock --global --platform linux-x64 --platform macos-arm64
chezmoi apply
```

The install hook and `mup` use `/` as the working directory so a project's local
mise config cannot add tools or change the versions selected for this operation.

Run `mup` to update the floating tools. It resolves every declared tool for both
`linux-x64` and `macos-arm64` no matter which machine runs it, then installs
what the lock holds for that machine. Refreshing the lock is deliberately not a
per-machine job. `mise lock` prunes the entries a run does not resolve, so a
host-scoped refresh drops the other platform's artifacts for every tool it
moves, and a Linux-scoped one deletes the macOS-only records outright. Review
and commit the resulting `dot_config/mise/mise.lock` change.

`mup` does not update the mise binary. Every host runs the same upstream
release, pinned by version and per-platform tarball checksum under `mise` in
[`.chezmoidata/versions.yaml`](../../.chezmoidata/versions.yaml).
`run_before_00-install-mise.sh.tmpl` runs before every other hook on each
apply. When `~/.local/bin/mise` reports a different version, it downloads the
pinned tarball, verifies its checksum, and installs the binary, man page and
zsh and bash completions. It also installs mise's self-update instructions
file, which disables `mise self-update` and points at the pin. The other hooks
call `~/.local/bin/mise` by path.

To update mise, change the version and both checksums, taking the checksums
from the release's `SHASUMS256.txt`. Then apply on each host, and after that
run `mup`. The tool installation hook also reruns when the pin changes. A shared version
means a lock refresh gives the same result whichever host runs it.

Omarchy's `mise-bin` package stays installed, because Omarchy's own scripts
call mise. `omarchy update` keeps upgrading it, but `~/.local/bin` precedes
`/usr/bin` on the managed PATH, so the pinned release is the one that runs.
Both binaries share the same data directory. The drift hook warns when `mise`
on PATH resolves anywhere other than `~/.local/bin/mise`.

After each apply, `run_after_tool-drift.sh.tmpl` reports duplicate manual
installs. On Omarchy it ignores audited stock launchers only when their
location and complete contents match. Modified launchers still produce a
warning. The managed mise shims precede the stock launchers on PATH.

The hook also reports installed versions that mise considers prunable, excluding
every version retained by the source-tree lock. Review those entries and use
`mise uninstall <tool>@<version>` for each version you choose to remove.
Avoid blanket `mise prune --tools` cleanup: normal global config can mark a
locked version as unused when a floating declaration selects a newer installed
version. The next apply that runs the install hook would install the locked
version again. The drift report changes nothing.

mise hides releases younger than a day, so a compromised publish has time to be
pulled before it lands here. The coding agents ship several times a day, which
is the whole reason they float, so `minimum_release_age_excludes` in the shared
configuration waives the cooldown for those entries only. It belongs in the
configuration rather than in `mup`'s environment because `mise lock` and
`mise install` both read it. Waiving the cooldown for the version bump alone
would resolve a version that the install, and every later `chezmoi apply`, then
refuses.
