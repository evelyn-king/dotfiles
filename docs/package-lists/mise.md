# mise tool list

mise installs the same language runtimes and user-level CLI tools on macOS and
Linux. Their declarations live in
[`dot_config/mise/conf.d/`](../../dot_config/mise/conf.d/).

The TOML files are the source of truth for requested versions. Most tools have
exact pins. Coding agents, `gh`, and `usage` track `latest` by design, while
Rust tracks the stable release channel. On both platforms,
[`dot_config/mise/mise.lock`](../../dot_config/mise/mise.lock) resolves them to
reviewable versions and checksums for `linux-x64` and `macos-arm64` where the
backend exposes a fixed artifact. The Rust entry remains `stable`; rustup
resolves that channel when mise installs or updates it.

## Tool ownership

Every tool lives in
[`10-dotfiles.toml`](../../dot_config/mise/conf.d/10-dotfiles.toml), and both
platforms install all of it. There is no per-platform declaration file.

Omarchy ships its own `herdr`, `usage` and `tree-sitter-cli` packages, so on
Linux those three commands exist twice. The mise shims lead `/usr/bin` on
`PATH`, so the pinned version is the one that runs. That overlap is chosen
rather than tolerated: pinning one version per tool across both machines is
worth more here than deferring to whatever Arch last shipped, which on the last
survey trailed 5.1.0 to 6.6.1 on `usage` and 0.26.9 to 0.26.13 on
`tree-sitter`. Nothing uninstalls the system copies, so anything invoking them
by absolute path still gets the packaged build.

`herdr` is the one to watch. Omarchy migration `1786273938` removes a
mise-installed `herdr` precisely because a stale client can shadow the packaged
one with an older wire protocol, and this declaration puts it back. If an
Omarchy update ever moves the herdr protocol, either bump the pin here in the
same session or drop the `herdr` line and let the package own it again.

`~/.config/mise/config.toml` has higher precedence than the managed `conf.d`
file, and a leftover `conf.d/20-macos.toml` from before the platforms were
unified outranks `10-dotfiles.toml` the same way. `run_before_10-migrate-retired-configs.sh`
removes either one when its contents match an audited version, and preserves
and warns about anything else. If it warns, move any wanted declarations to
`10-dotfiles.toml`, then remove the conflicting file.

`unidep` installs with its `all` extra, and `pre-commit` installs with
`pre-commit-uv`. Those additions are recorded as `uvx_args` in the shared
configuration.

Pixi is managed exclusively by mise on both Linux and macOS, with its version
pinned in `10-dotfiles.toml`. Do not add it to pacman or Nix package lists.
`~/.pixi/bin` remains on PATH for tools installed through Pixi itself.

## Installation and updates

`run_onchange_after_mise-install.sh.tmpl` runs the install after the
configuration file changes. Its npm and pipx backends require `bun` and `uv`.
On Omarchy the hook installs either missing package with `omarchy pkg add`
before running mise. Nix supplies both commands on macOS; other hosts must
provide them before applying. Apply a declaration change with:

```bash
chezmoi apply
```

Run `mup` to update floating tools. It resolves every declared tool for both
`linux-x64` and `macos-arm64` no matter which machine runs it, then installs
what the lock holds for that machine. Refreshing the lock is deliberately not a
per-machine job: `mise lock` prunes the entries a run does not resolve, so a
host-scoped refresh drops the other platform's artifacts for every tool it moves,
and a Linux-scoped one deletes the three macOS-only records outright. Review and
commit the resulting `dot_config/mise/mise.lock` change. `mup` does not update
the mise binary. Nix owns that binary on macOS, so update the flake
inputs and run `nix-switch`. Omarchy owns it through `mise-bin`, which the
normal `omarchy update` process updates.

After each apply, `run_after_tool-drift.sh.tmpl` reports duplicate manual
installs and old mise versions that `mise prune --tools` can remove. The report
does not change installed tools.

mise hides releases younger than a day so a compromised publish has time to be
pulled before it lands here. The coding agents ship several times a day, which
is the whole reason they float, so `minimum_release_age_excludes` in the shared
configuration waives the cooldown for those entries only. It belongs in the
configuration rather than in `mup`'s environment because `mise lock` and `mise
install` both read it: waiving the cooldown for the bump alone resolves a
version that the install, and every later `chezmoi apply`, then refuses.
