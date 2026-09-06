# mise tool list

mise installs the same language runtimes and user-level CLI tools on macOS and
Linux. The declarations live in
[`dot_config/mise/conf.d/`](../../dot_config/mise/conf.d/), and
[`10-dotfiles.toml`](../../dot_config/mise/conf.d/10-dotfiles.toml) is the
source of truth for which tools exist and which version each one requests. Read
that file for the list. This page covers the ownership rules and the update
workflow.

Both platforms install everything declared there. There is no per-platform
declaration file.

Most tools carry exact pins. The coding agents, `gh` and `usage` track `latest`
by design, and Rust tracks the stable release channel. On both platforms,
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
Linux those three commands exist twice. The mise shims lead `/usr/bin` on
`PATH`, so the pinned version is the one that runs. That overlap is chosen
rather than tolerated. Pinning one version per tool across both machines is
worth more here than deferring to whatever Arch last shipped, which has trailed
the pinned versions, in `usage`'s case by a major release. Nothing uninstalls
the system copies, so anything invoking them by absolute path still gets the
packaged build.

`herdr` is the one to watch. Omarchy migration `1786273938` removes a
mise-installed `herdr` precisely because a stale client can shadow the packaged
one with an older wire protocol, and this declaration puts it back. If an
Omarchy update ever moves the herdr protocol, either bump the pin here in the
same session or drop the `herdr` line and let the package own it again.

Pixi is managed only by mise, on both platforms. Do not add it to pacman or Nix
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

`run_onchange_after_mise-install.sh.tmpl` runs the install after the
configuration file changes. Its npm and pipx backends need `bun` and `uv`. On
Omarchy the hook installs either missing package with `omarchy pkg add` before
running mise. Nix supplies both commands on macOS; any other host has to provide
them before applying. Apply a declaration change with:

```bash
chezmoi apply
```

Run `mup` to update the floating tools. It resolves every declared tool for both
`linux-x64` and `macos-arm64` no matter which machine runs it, then installs
what the lock holds for that machine. Refreshing the lock is deliberately not a
per-machine job. `mise lock` prunes the entries a run does not resolve, so a
host-scoped refresh drops the other platform's artifacts for every tool it
moves, and a Linux-scoped one deletes the macOS-only records outright. Review
and commit the resulting `dot_config/mise/mise.lock` change.

`mup` does not update the mise binary. Nix owns that binary on macOS, so update
the flake inputs and run `nix-switch`. Omarchy owns it through `mise-bin`, which
the normal `omarchy update` updates.

After each apply, `run_after_tool-drift.sh.tmpl` reports duplicate manual
installs and old mise versions that `mise prune --tools` can remove. The report
changes nothing.

mise hides releases younger than a day, so a compromised publish has time to be
pulled before it lands here. The coding agents ship several times a day, which
is the whole reason they float, so `minimum_release_age_excludes` in the shared
configuration waives the cooldown for those entries only. It belongs in the
configuration rather than in `mup`'s environment because `mise lock` and
`mise install` both read it. Waiving the cooldown for the version bump alone
would resolve a version that the install, and every later `chezmoi apply`, then
refuses.
