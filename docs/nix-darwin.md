# nix-darwin

macOS packages are declared in [`nix/flake.nix`](../nix/flake.nix) and applied
with nix-darwin. This replaces Homebrew as the package manager; chezmoi keeps
ownership of dotfiles.

## Commands

```bash
darwin-rebuild switch --flake ~/.local/share/chezmoi/nix#lagrange
darwin-rebuild build  --flake ~/.local/share/chezmoi/nix#lagrange   # no activation
nix flake update --flake ~/.local/share/chezmoi/nix                 # move the pin
```

`nix/` is listed in `.chezmoiignore`: it is repo content, not a dotfile, so it
is read from the source tree directly rather than rendered into `$HOME`.

`flake.lock` pins nixpkgs to an exact commit. It is committed deliberately —
updating the world is `nix flake update`, reviewed as a diff, never implicit.

## Division of labour

- **chezmoi** — dotfiles. Do not enable home-manager's program modules; they
  overlap with chezmoi and the two will fight over `~/.zshrc`.
- **nix-darwin** — command-line packages. GUI apps are installed by hand; see
  below for why.
- **Determinate Nix** — the daemon and `/etc/nix/nix.conf`. Hence
  `nix.enable = false` in the flake; nix-darwin must not manage Nix here.

## Coverage

All 56 former Homebrew formulae are in nixpkgs for `aarch64-darwin`. Four are
named differently: `git-delta`→`delta`, `node`→`nodejs`, `pinentry-mac`→
`pinentry_mac`, `dust`→`dust` (the old `du-dust` alias is gone).

Of 17 casks, 1 comes from nixpkgs: `emacs-macport`. Eight more are packaged for
Darwin but deliberately not used — see below.

## Applications installed by hand

These are not managed by Nix. Install from the vendor `.dmg`; most self-update.

| App | Why not Nix |
|---|---|
| 1Password | Privileged helper; browser integration verifies code signatures |
| Tailscale | Installs a network system extension |
| Zed | Self-updater; nags against the read-only store |
| Obsidian | Self-updater; nags against the read-only store |
| Zotero | Self-updater; nags against the read-only store |
| Ghostty | Sparkle self-updater; nags against the read-only store |
| iTerm2 | Sparkle self-updater; nags against the read-only store |
| codex | Self-updater. A CLI, not an app — install via its own installer |
| Dropbox | Linux-only in nixpkgs |
| FreeCAD | Linux-only in nixpkgs |
| Bambu Studio | Linux-only in nixpkgs |
| Claude | Not packaged |
| Zen | Not packaged |
| BalenaEtcher | Not packaged |
| dot | Not packaged |
| Adobe Acrobat Reader | Not packaged (Preview covers most of this) |

The first eight are a deliberate choice rather than a gap — all are packaged for
Darwin and build fine. 1Password and Tailscale are excluded because Nix
repackaging can break the signature chains their privileged components depend
on. The other six are excluded because they self-update.

`codex` is the only command-line tool among these, but it leaves no gap: it is
already installed globally via bun at `~/.bun/bin/codex`, and `$BUN_INSTALL/bin`
sits ahead of the Nix profiles in `dot_zshrc`, so that copy was winning anyway.

## Why self-updating apps are not managed here

App bundles in the store are mode `555` and owned by `root`, so a self-updater
running as your user cannot replace one. It downloads, then fails at install —
every time, forever. Silencing that means disabling each app's updater and
accepting that the app now moves only when you run `nix flake update`.

For a terminal or an editor you launch daily, that is worse than letting the
vendor's updater do its job. So the rule here is: **if an app updates itself,
Nix does not manage it.** Emacs is the one app bundle in the closure, because it
has no updater.

Should that ever be revisited, two cautions apply:

- **Never authenticate an updater's admin prompt.** `/nix` is not mounted
  read-only — immutability is enforced by permissions alone, and root overrides
  them. Sparkle can escalate through its privileged installer helper, and a
  successful write corrupts a store path whose name is its content hash. Detect
  with `nix store verify --all`, repair with `nix-store --repair-path`.
- **Watch `~/Applications`.** Some updaters fall back to installing there when
  they cannot write the original. Launch Services may then prefer that copy,
  silently reintroducing an unmanaged self-updating app.

## Notes

- **Not everything comes from Nix.** `.chezmoidata/versions.yaml` still pins
  `keychain` (held back pending a check against 3.x) plus the tmux and vim
  plugins, which are fetched as chezmoi externals. `micromamba` and the GUI
  applications are installed by hand. Language-level package managers — `bun`,
  `cargo`, `go install`, `uv`, `pixi` — fetch their own binaries as before, and
  their bin directories sit ahead of the Nix profiles in `dot_zshrc`, so
  anything installed through them shadows the Nix copy.
- **Unfree.** Every package in the closure is free, so no `allowUnfree` escape
  hatch is configured and adding an unfree package will fail the build until one
  is. Prefer a narrow `allowUnfreePredicate` allowlist over blanket
  `allowUnfree` so each exception stays a deliberate edit.
- **Emacs.** `emacs-macport` is not `emacs-plus`; it carries a different patch
  set. Verify Doom still builds after the switch — see
  `run_once_after_install-doom-emacs.sh.tmpl`.
- **Ghostty.** If ever reinstated, the attribute is `ghostty-bin` — the source
  build is Linux-only in nixpkgs.
- **micromamba is not managed by Nix.** nixpkgs 2.6.2 has no `aarch64-darwin`
  substitute and fails to build from source — libmamba hits a `fmt`/libcxx-21
  incompatibility (`no member named 'format' in namespace 'fmt'`). Because a
  broken package in `environment.systemPackages` fails the entire system
  closure, it is commented out of the flake. Install the standalone binary into
  `~/.local/bin` instead, which is first on `PATH`:

  ```bash
  curl -Ls https://micro.mamba.pm/api/micromamba/osx-arm64/latest \
    | tar -xvjO bin/micromamba > ~/.local/bin/micromamba
  chmod +x ~/.local/bin/micromamba
  ```

  Retry `pkgs.micromamba` after a `nix flake update` once the Darwin build is
  fixed upstream. The env store at `$MAMBA_ROOT_PREFIX`
  (`~/.local/opt/micromamba`, set in `dot_zshenv`) is data, not a competing
  install — leave it in place regardless.
- **Spotlight.** The closure ships two app bundles, `Emacs.app` and
  `pinentry-mac.app` (a GPG helper that comes along with `pinentry_mac`, not a
  user-facing app). Both are symlinked into `/Applications/Nix Apps`, which
  Spotlight and the Dock index poorly. If Emacs proves hard to launch from
  Spotlight, `mac-app-util` writes real aliases instead; it is a third-party
  flake, so it is documented in the flake as opt-in rather than enabled.
- **Provenance.** Relevant mainly if GUI casks are ever reinstated: the Darwin
  GUI packages in nixpkgs are fixed-output derivations wrapping vendor
  `.dmg`/`.zip` artifacts rather than source builds. The gain over a Homebrew
  cask is a pinned, reviewable hash — casks with `version :latest` use
  `sha256 :no_check` and verify nothing — but the vendor binary is still
  trusted.
