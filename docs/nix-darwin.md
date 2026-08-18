# nix-darwin

macOS packages are declared in [`nix/flake.nix`](../nix/flake.nix) and applied
with nix-darwin. chezmoi keeps ownership of dotfiles.

## Commands

```bash
darwin-rebuild switch --flake ~/.local/share/chezmoi/nix#lagrange
darwin-rebuild build  --flake ~/.local/share/chezmoi/nix#lagrange   # no activation
nix flake update --flake ~/.local/share/chezmoi/nix                 # move the pin
```

`nix/` is listed in `.chezmoiignore`: it is repo content, not a dotfile, so it
is read from the source tree directly rather than rendered into `$HOME`.

`chezmoi apply` reminds you to switch, but never switches.
`run_after_darwin-rebuild.sh.tmpl` runs on every apply and compares the running
system against the flake, printing the `darwin-rebuild switch` line for as long
as the two differ. It nags until you act, rather than once when the file
changed; an apply on a current system is silent. The check costs one `nix eval`,
about 2.5s.

**It stops there on purpose.** Activation requires root, and `chezmoi apply` is
a routine command that must not escalate. The script is rendered from repo
content, so a `sudo` call inside it would grant root to anything that reaches
the source tree — a bad commit, a compromised upstream, a careless merge — at
the moment you run an unrelated apply. Activation stays a separate command you
type knowingly.

What it compares is deliberate. `config.system.path` and
`config.system.build.etc` are matched against `/run/current-system/sw` and
`/run/current-system/etc`; the system's own `outPath` is **not** used. That
top-level path embeds `system.configurationRevision`, which is the git revision
of this entire repo — so every commit, including ones nowhere near `nix/`, would
report drift that no package or `/etc` file reflects. The two halves compared
instead carry no revision, so a difference is always a real one. The gap is
narrow but worth knowing: a change that alters neither the package set nor
`/etc` — a launchd job, say — will not be caught.

`flake.lock` pins nixpkgs to an exact commit. It is committed deliberately —
updating the world is `nix flake update`, reviewed as a diff, never implicit.

## Division of labour

- **chezmoi** — dotfiles. Do not enable home-manager's program modules; they
  overlap with chezmoi and the two will fight over `~/.zshrc`.
- **nix-darwin** — command-line packages and the system font. GUI apps are
  installed by hand; see below for why.
- **mise** — language runtimes and global CLI tools, declared in
  `dot_config/mise/conf.d/10-dotfiles.toml`. Everything above the system closure.
- **Determinate Nix** — the daemon and `/etc/nix/nix.conf`. Hence
  `nix.enable = false` in the flake; nix-darwin must not manage Nix here.

`bun` and `uv` sit on the boundary and stay in the flake: mise shells out to
them for its `npm:` and `pipx:` backends, so installing them through mise would
be a needless ordering dependency. `rustup` is also in the flake — it is
already Rust's own version manager, and `dot_rustup/settings.toml` configures
it. See [`bootstrap.md`](bootstrap.md) for the layering as a whole.

## Applications installed by hand

These are not managed by Nix. Install from the vendor `.dmg`; most self-update.

| App | Why not Nix |
|---|---|
| Tailscale | Installs a network system extension |
| Zed | Self-updater; nags against the read-only store |
| Obsidian | Self-updater; nags against the read-only store |
| Zotero | Self-updater; nags against the read-only store |
| Ghostty | Sparkle self-updater; nags against the read-only store |
| iTerm2 | Sparkle self-updater; nags against the read-only store |
| Rancher Desktop | Privileged helper and a VM; supplies `docker`, `kubectl` and `helm` via `~/.rd/bin` |
| Claude Code CLI | Self-updater, into `~/.local/share/claude/versions/` |
| Dropbox | Linux-only in nixpkgs |
| FreeCAD | Linux-only in nixpkgs |
| Bambu Studio | Linux-only in nixpkgs |
| Claude | Not packaged |
| Zen | Not packaged |
| BalenaEtcher | Not packaged |
| dot | Not packaged |
| Adobe Acrobat Reader | Not packaged (Preview covers most of this) |

The first six are a deliberate choice rather than a gap — all are packaged for
Darwin and build fine. Tailscale and Rancher Desktop are excluded because Nix
repackaging can break the signature chains their privileged components depend
on. The rest of that group is excluded because it self-updates.

Two of these are command-line tools rather than apps. `docker`, `kubectl` and
`helm` come from Rancher Desktop, which is why `~/.rd/bin` is on `PATH` in
`dot_zshrc`; the `d` alias depends on it. The Claude Code CLI manages its own
versions under `~/.local/share/claude`. Neither leaves a gap, but both are
invisible to `darwin-rebuild`, so a fresh machine needs them installed by hand
— see [`bootstrap.md`](bootstrap.md).

`codex` used to be on this list. It is now a mise entry
(`npm:@openai/codex`), pinned like everything else.

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

- **Not everything comes from Nix.** `.chezmoidata/versions.yaml` pins the vim
  plugins, which are fetched as chezmoi externals, and the Doom revision.
  Runtimes and global CLI tools come from mise. The GUI applications are
  installed by hand. Language-level package managers — `cargo`, `go install`,
  `pixi` — still fetch their own binaries, and their bin directories sit ahead
  of the Nix profiles in `dot_zshrc`, so anything installed through them
  shadows the Nix copy. That ordering also means a stale binary left in
  `~/.local/bin` will win over the Nix one — remove it when a tool moves into
  the flake. mise is the exception: it prepends its own directories at each
  prompt, so it wins over both. The migration checklist in
  [`bootstrap.md`](bootstrap.md#migrating-an-existing-machine) exists because
  neither rule protects you from a tool whose mise install quietly failed.
- **Unfree.** Every package in the closure is free, so no `allowUnfree` escape
  hatch is configured and adding an unfree package will fail the build until one
  is. Prefer a narrow `allowUnfreePredicate` allowlist over blanket
  `allowUnfree` so each exception stays a deliberate edit.
- **Emacs.** `emacs-macport` carries its own patch set; check Doom still builds
  against it after a flake update — see
  `run_once_after_install-doom-emacs.sh.tmpl`.
- **Ghostty.** If it is ever added here, the attribute is `ghostty-bin` — the
  source build is Linux-only in nixpkgs.
- **Fonts.** `fonts.packages` supplies `nerd-fonts.caskaydia-cove`, whose family
  is `CaskaydiaCove Nerd Font` — the exact name `dot_config/ghostty` asks for,
  and the glyph source starship and `eza --icons` need. It used to be a
  hand-dropped `.otf` in `~/Library/Fonts`; if that copy is still there, delete
  it, since two installs of one family compete.
- **micromamba comes from mise, not Nix.** nixpkgs has no `aarch64-darwin`
  substitute and it fails to build from source — libmamba hits a
  `fmt`/libcxx-21 incompatibility (`no member named 'format' in namespace
  'fmt'`) — and a broken package in `environment.systemPackages` fails the
  entire closure. mise installs the same upstream standalone binary, pinned in
  `dot_config/mise/conf.d/10-dotfiles.toml`, which is strictly better than the `curl | tar`
  this used to require. The env store at `$MAMBA_ROOT_PREFIX`
  (`~/.local/opt/micromamba`, set by the shared shell environment template) is data, not a competing
  install — leave it in place regardless.
- **Spotlight.** The closure ships two app bundles, `Emacs.app` and
  `pinentry-mac.app` (a GPG helper that comes along with `pinentry_mac`, not a
  user-facing app). Both are symlinked into `/Applications/Nix Apps`, which
  Spotlight and the Dock index poorly. If Emacs proves hard to launch from
  Spotlight, `mac-app-util` writes real aliases instead; it is a third-party
  flake, so it is documented in the flake as opt-in rather than enabled.
