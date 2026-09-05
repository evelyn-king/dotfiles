# macOS package list

Apple Silicon macOS machines use nix-darwin. The declaration is
[`nix/flake.nix`](../../nix/flake.nix), which is repository content rather than
a home file and is listed in `.chezmoiignore`. Read the flake for the actual
package, cask and App Store lists. This page covers only the ownership rules
and the manual steps around them.

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
| `nix/flake.nix` `homebrew.masApps` | Mac App Store applications |
| `dot_config/mise/conf.d/10-dotfiles.toml` | language runtimes and global CLI tools |

Anything mise manages is deliberately absent from the Nix package list.

The Xcode Command Line Tools supply `cc`, `c++`, the linker and the related
build commands. GCC is not installed globally, because its unprefixed commands
would replace Apple's toolchain on `PATH`.

The flake owns the entire Homebrew prefix. Each activation removes every
formula, cask and tap that `nix/flake.nix` does not declare. Add a package to
the flake before installing it with Homebrew if it has to survive the next
`darwin-rebuild switch`. Homebrew itself must already be installed;
nix-darwin drives it but does not install it.

## Cask update policy

Casks are non-greedy (`greedyCasks = false`). Nearly all of the declared casks
set `auto_updates`, so each vendor's own updater owns its version and activation
leaves it alone. That avoids a fortnightly fight with those updaters, and avoids
re-running vendor `pkg` installers under `sudo`. `upgrade = true` still picks up
the handful of casks that do not update themselves.

Two casks opt back in with `greedy = true`, because they sat months out of date
under their own updaters despite advertising `auto_updates`. The flake marks
them inline. Close a greedy cask's application before a switch, since activation
can replace a running bundle.

AeroSpace starts at login after its first launch, but macOS still requires a
one-time Accessibility approval. The cold-start guide records that handoff and
the command that verifies the running application.

## Adopt existing applications

Before the first activation on an existing Mac, let Homebrew adopt applications
installed by another method. Otherwise cask installation stops when it finds the
existing application in `/Applications`.

Derive the cask list from the flake rather than from a list written here. A
hardcoded list goes stale on the next cask change; this reads the current
declaration:

```bash
casks=$(nix eval --json \
  "$(chezmoi source-path)/nix#darwinConfigurations.macbook.config.homebrew.casks" \
  | python3 -c 'import json,sys; print(" ".join(c["name"] for c in json.load(sys.stdin)))')
printf '%s\n' "$casks"
brew install --cask --adopt $casks
brew list --cask
```

nix-darwin normalizes each entry to an attribute set, so `.name` covers both
plain strings and the `{ name = ...; greedy = true; }` form.

Run this after installing Nix and Homebrew and before the first activation. It
adopts any application already in `/Applications`, installs any declared cask
that is missing, and does nothing for casks Homebrew already manages. Installing
the missing ones matches the flake's declared cask ownership. To skip one,
remove it from `nix/flake.nix` before activation rather than working around the
collision.

To see the collisions before acting, list declared casks that Homebrew does not
yet manage:

```bash
comm -23 <(printf '%s\n' $casks | sed 's|.*/||' | sort) <(brew list --cask | sort)
```

`system.primaryUser` in the flake must match the macOS short account name
(`id -un`) or activation fails.

## Mac App Store applications

`homebrew.masApps` declares the App Store applications and `mas` installs them.
nix-darwin puts `mas` on the activation PATH, so the flake does not declare it
as a formula.

Sign in to the App Store before the first activation. The account that owns
these purchases has to be signed in, or activation cannot install or upgrade
them. `mas signin` does not work on current macOS, so sign in through the App
Store application. The repository cannot automate this.

Xcode is one of the declared applications and is a multi-gigabyte download, so
it adds noticeable time to the first activation. It is separate from the Xcode
Command Line Tools that the cold-start guide installs with
`xcode-select --install`; those tools are the compiler and linker the rest of
this configuration depends on, and installing Xcode does not remove the need for
them. Launch Xcode once after it installs to accept its license.

Removing an entry from `masApps` does not uninstall the application, even under
`cleanup = "uninstall"`. Delete those by hand.

Get the id for a new entry from the installed bundle:

```bash
mdls -name kMDItemAppStoreAdamID -raw /Applications/<name>.app
```

## Drift

`run_after_darwin-rebuild.sh.tmpl` compares the running system against the flake
on every `chezmoi apply` and nags when they differ. It deliberately does not
activate. `darwin-rebuild switch` requires root, and `chezmoi apply` must never
escalate.

`run_after_tool-drift.sh.tmpl` reports commands that an earlier `PATH` entry
shadows ahead of `/run/current-system/sw/bin`. It also reports duplicate
user-installed copies of mise tools, and old mise versions eligible for pruning.
The check removes nothing.
