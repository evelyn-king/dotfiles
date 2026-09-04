# mise tool list

mise installs the shared language runtimes and user-level CLI tools on macOS
and Linux, plus three macOS-only tools. Their declarations live in
[`dot_config/mise/conf.d/`](../../dot_config/mise/conf.d/).

The TOML files are the source of truth for requested versions. Most tools have
exact pins. Coding agents, `gh`, and `usage` track `latest` by design, while
Rust tracks the stable release channel. On both platforms,
[`dot_config/mise/mise.lock`](../../dot_config/mise/mise.lock) resolves them to
reviewable versions and checksums for `linux-x64` and `macos-arm64` where the
backend exposes a fixed artifact. The Rust entry remains `stable`; rustup
resolves that channel when mise installs or updates it.

## Tool ownership

The shared tools live in
[`10-dotfiles.toml`](../../dot_config/mise/conf.d/10-dotfiles.toml). macOS adds
`herdr`, `usage`, and `tree-sitter-cli` from
[`20-macos.toml`](../../dot_config/mise/conf.d/20-macos.toml). Omarchy supplies
those three as system packages, so installing them with mise on Linux would
split update ownership and put stale versions ahead of `/usr/bin`.

`~/.config/mise/config.toml` has higher precedence than the managed `conf.d`
file. The migration script removes audited legacy versions but preserves and
warns about unrecognized content. If it warns, move any wanted declarations to
`10-dotfiles.toml`, then remove the conflicting file.

`unidep` installs with its `all` extra, and `pre-commit` installs with
`pre-commit-uv`. Those additions are recorded as `uvx_args` in the shared
configuration.

## Installation and updates

`run_onchange_after_mise-install.sh.tmpl` runs the install after the
configuration file changes. Its npm and pipx backends require `bun` and `uv`.
On Omarchy the hook installs either missing package with `omarchy pkg add`
before running mise. Nix supplies both commands on macOS; other hosts must
provide them before applying. Apply a declaration change with:

```bash
chezmoi apply
```

Run `mup` to update floating tools and their platform-specific lock resolution.
Review and commit the resulting `dot_config/mise/mise.lock` change. Update mise
itself separately with `mise self-update`.

mise hides releases younger than a day so a compromised publish has time to be
pulled before it lands here. The coding agents ship several times a day, which
is the whole reason they float, so `minimum_release_age_excludes` in the shared
configuration waives the cooldown for those entries only. It belongs in the
configuration rather than in `mup`'s environment because `mise lock` and `mise
install` both read it: waiving the cooldown for the bump alone resolves a
version that the install, and every later `chezmoi apply`, then refuses.
