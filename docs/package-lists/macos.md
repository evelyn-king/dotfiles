# macOS package list

Apple Silicon macOS machines use nix-darwin. The declaration is
[`nix/flake.nix`](../../nix/flake.nix), which is repository content rather than
a home file and is listed in `.chezmoiignore`.

The flake lives in the source tree and `.chezmoi.toml.tmpl` pins `sourceDir` to
wherever the repo was cloned, so derive the path rather than hardcoding it:

```bash
darwin-rebuild switch --flake "$(chezmoi source-path)/nix#macbook"
nix flake update --flake "$(chezmoi source-path)/nix"   # move the pin
```

`nix-switch` is an alias for the first command, rendered with the source path
already resolved. `darwinConfigurations` defines only `macbook`, for
`aarch64-darwin`.

## Ownership

| Source | Owns |
| --- | --- |
| `nix/flake.nix` `environment.systemPackages` | system CLI packages |
| `nix/flake.nix` `homebrew.casks` | GUI applications |
| `dot_config/mise/conf.d/10-dotfiles.toml` | language runtimes and global CLI tools |

Anything managed by mise is deliberately absent from the Nix package list.

GUI applications come from Homebrew casks declared in the flake. nix-darwin
installs and upgrades them during `darwin-rebuild switch`, while keeping them
outside the read-only Nix store so their own updaters still work. Homebrew
itself must already be installed.

The flake owns the entire Homebrew prefix. Each activation removes every
formula, cask, and tap that is not declared in `nix/flake.nix`. Add a package
to the flake before installing it with Homebrew if it must survive the next
`darwin-rebuild switch`.

`system.primaryUser` in the flake must match the macOS short account name
(`id -un`) or activation fails.

## Drift

`run_after_darwin-rebuild.sh.tmpl` compares the running system against the
flake on every `chezmoi apply` and nags when they differ. It deliberately does
not activate. `darwin-rebuild switch` requires root, and `chezmoi apply` must
never escalate.
