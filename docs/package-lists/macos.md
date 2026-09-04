# macOS package list

Apple Silicon macOS machines use nix-darwin. Intel macOS is not supported. The
declaration is [`nix/flake.nix`](../../nix/flake.nix), which is repository
content rather than a home file and is listed in `.chezmoiignore`.

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

Anything managed by mise is deliberately absent from the Nix package list.
Both macOS and Omarchy use the stock `tldr` client; Nix owns it on macOS.
The Xcode Command Line Tools supply `cc`, `c++`, the linker, and related build
commands. GCC is not installed globally because its unprefixed commands would
replace Apple's toolchain on `PATH`.

GUI applications come from Homebrew casks declared in the flake. nix-darwin
installs and upgrades them during `darwin-rebuild switch`. Homebrew itself must
already be installed.

Casks are non-greedy (`greedyCasks = false`). 37 of the 40 declared casks set
`auto_updates`, so each vendor's own updater owns its version and activation
leaves it alone. This avoids a fortnightly fight with those updaters and avoids
re-running a `pkg` installer under `sudo` for the Microsoft suite,
google-drive, onedrive, cloudflare-warp, tailscale-app, zoom and the Logitech
pair.

`upgrade = true` still upgrades the three casks that do not self-update:
aerospace, basictex and dot.

Two casks opt back in with `greedy = true` because they rotted while installed
by hand despite advertising `auto_updates`:

| Cask | Why Homebrew forces it |
| --- | --- |
| `bartender` | sat months out of date under its own updater |
| `raindropio` | sat months out of date under its own updater |

Close those two before a switch, since activation can replace a running
bundle.

AeroSpace starts at login after its first launch. macOS still requires a
one-time Accessibility approval. The cold-start guide records that handoff and
the command used to verify the running application.

The flake owns the entire Homebrew prefix. Each activation removes every
formula, cask, and tap that is not declared in `nix/flake.nix`. Add a package
to the flake before installing it with Homebrew if it must survive the next
`darwin-rebuild switch`.

Pixi is supplied by [mise](mise.md) on both platforms. The next
`nix-switch` removes it from the Nix system package set.

## Adopt existing applications

Before the first activation on an existing Mac, let Homebrew adopt applications
that were installed by another method. Otherwise the cask installation stops
when it finds the existing application in `/Applications`.

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
that is missing, and is a no-op for casks Homebrew already manages. Installing
the missing ones is consistent with the flake's declared cask ownership. Remove
an unwanted cask from `nix/flake.nix` before activation rather than skipping
its collision.

To see the collisions before acting, list declared casks that Homebrew does not
yet manage:

```bash
comm -23 <(printf '%s\n' $casks | sed 's|.*/||' | sort) <(brew list --cask | sort)
```

`system.primaryUser` in the flake must match the macOS short account name
(`id -un`) or activation fails.

## Mac App Store applications

`homebrew.masApps` declares seven App Store applications, installed with `mas`.
nix-darwin puts `mas` on the activation PATH, so it is not declared as a
formula.

| Application | Adam ID |
| --- | --- |
| Amazon Kindle | 302584613 |
| DaisyDisk | 411643860 |
| Keynote | 409183694 |
| Magnet | 441258766 |
| Slack | 803453959 |
| WireGuard | 1451685025 |
| Xcode | 497799835 |

**Sign in to the App Store before the first activation.** The account that owns
these purchases must be signed in, or activation cannot install or upgrade
them. `mas signin` does not work on current macOS; sign in through the App
Store application itself. This is manual work that the repository cannot
automate.

Xcode is a multi-gigabyte download and adds noticeable time to the first
activation. It is separate from the Xcode Command Line Tools that the
cold-start guide installs with `xcode-select --install`; the tools are the
compiler and linker the rest of this configuration depends on, and installing
Xcode does not remove the need for them. After Xcode installs, launch it once
to accept its license.

Removing an entry from `masApps` does **not** uninstall the application, even
under `cleanup = "uninstall"`. Delete those by hand.

Get the id for a new entry from the installed bundle:

```bash
mdls -name kMDItemAppStoreAdamID -raw /Applications/<name>.app
```

## Drift

`run_after_darwin-rebuild.sh.tmpl` compares the running system against the
flake on every `chezmoi apply` and nags when they differ. It deliberately does
not activate. `darwin-rebuild switch` requires root, and `chezmoi apply` must
never escalate.

`run_after_tool-drift.sh.tmpl` reports commands that an earlier `PATH` entry
shadows ahead of `/run/current-system/sw/bin`. It also reports duplicate
user-installed copies of mise tools and old mise versions eligible for pruning.
The check does not remove anything.
