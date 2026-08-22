# Layers

These dotfiles run on machines with wildly different surfaces: a Mac with
nix-darwin, an Omarchy desktop, and an unprivileged shell on somebody else's
Ubuntu box. Layers are how one source tree serves all three without three
branches to merge.

## The floor

The base layer is not "Ubuntu LTS". It is the smallest machine worth
configuring at all:

- POSIX `sh`. Not bash, not zsh — a minimal image may have neither.
- No root, and no expectation of ever getting it.
- A writable `~/.local/bin`.
- `curl` or `wget`, and `sha256sum` or `shasum`.

Ubuntu LTS with sudo is not the floor; it is the floor plus the `root` and
`apt` layers. Defining base this way is what stops "it works on my Mac" from
leaking into files that a locked-down box also reads. Everything in base is
either pure text or guarded at runtime, and the shell entry points are written
in POSIX sh for exactly this reason — see [shell-startup.md](shell-startup.md).

Anything not claimed by a layer in [`.chezmoidata/layers.yaml`](../.chezmoidata/layers.yaml)
is base. That is most of the tree, and it should stay that way.

## Two clocks

Layer resolution runs on two different schedules, and which one a fact belongs
to is the main design decision in this system.

| | Slow clock | Fast clock |
|---|---|---|
| Where | `.chezmoi.toml.tmpl` → `~/.config/chezmoi/chezmoi.toml` | `.chezmoitemplates/layers.yaml.tmpl` |
| When | Once, at `chezmoi init` | Every `chezmoi apply` |
| Holds | `facts`: root, libc, desktop, prefixWritable | Everything else |
| Costs | A subprocess per probe | A map lookup or a `PATH` scan |

The split is not arbitrary. chezmoi renders the config template exactly once
and freezes the result, so anything expensive belongs there — and the facts it
holds are precisely the ones that do not change without a deliberate act:
being granted sudo, attaching a display, moving to a musl host. Everything on
the fast clock is free to evaluate, so capability layers follow the machine as
tools come and go.

When you do one of those deliberate acts, re-run `chezmoi init`. chezmoi warns
you when the template itself changes, but it cannot know that your sudo rights
did.

Run `layers` to see the current state of both clocks.

## Writing a layer

One block in `.chezmoidata/layers.yaml`. Nothing else in the repo needs
editing — `.chezmoiignore` is a generic loop over this data.

```yaml
  omarchy:
    detect:
      osRelease: omarchy
      requires: [desktop]
    owns:
      - .config/hypr
      - .config/omarchy
    scripts: [omarchy-*.sh]
```

Predicates AND together. The vocabulary is deliberately small — `os`,
`osRelease`, `has`, `hasAny`, `fact`, `requires`, `conflicts` — because a
layer that needs a richer predicate than these is usually a sign the axes are
wrong. A layer with no `detect` block never activates on its own and must be
named in `layerForce`.

`implies` runs after the predicate sweep and turns other layers on. It exists
for one specific problem, described under the standalone layer below.

Two ownership rules apply:

1. **A path has at most one owning layer.** Two layers claiming one path means
   the axes overlap; split the file instead. The
   [layer lint](../scripts/lint-layers.sh) enforces this.
2. **A `has:`-keyed layer may only add.** See the next section for why.

## Layers are not toggles

`.chezmoiignore` makes chezmoi stop *managing* a path. It does not delete an
already-applied copy. Turning a layer off therefore leaves its files in `$HOME`
as unmanaged debris.

This is fine — desirable, even — for layers keyed on a tool being present:
install cargo and `.cargo/config.toml` appears; uninstall it and the file stays
until you remove it yourself. Nothing breaks.

It is a trap for anything else. If you want a layer that genuinely removes what
it stops owning, that is `.chezmoiremove` or a `remove_` entry, and it is a
much sharper tool: a detection blip then deletes real files. Nothing in this
repo does that today, and adding it should be a deliberate, argued change.

## The standalone layer

The interesting one, and the reason the floor is defined the way it is.

`standalone` is the only layer that activates on an **absence**:

```yaml
    detect:
      fact: {prefixWritable: "true"}
      conflicts: [root, nix]
```

No root and no nix means nothing on this machine will install software for us,
so the dotfiles have to do it themselves. Its entry point is
[`bootstrap-standalone.sh`](../bootstrap-standalone.sh), the counterpart to
`bootstrap.sh`:

```sh
curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/main/bootstrap-standalone.sh | sh
```

That script installs exactly one binary — chezmoi — and hands off. Two details
carry most of the weight:

- **`chezmoi init --use-builtin-git`.** A locked-down box frequently has no
  git, and git is not something you can drop in as a static binary the way the
  Go and Rust tools can. chezmoi's built-in client clones over HTTPS without
  it, which is what makes a git-less bootstrap possible at all.
- **mise is fetched by the layer, not the bootstrap.** Once chezmoi is on the
  box the repo can describe its own provisioning, and mise resolves prebuilt
  artefacts for everything else. One static binary unlocks the rest of the tool
  set with no compiler and no privilege escalation.

### Why `implies: [mise]`

Detection-driven layers have a bootstrapping circularity: on the first apply,
mise is not installed yet, so the `mise` layer is off, so its config is never
written — and the apply that installs mise leaves the machine needing a second
apply to configure it.

`standalone` declares `implies: [mise]` to break this. It is about to install
mise, so it turns the layer on now and the config lands on the same pass. This
is the general answer for any layer that provisions what a later layer detects.

It does not fully eliminate two-pass convergence. The `rust`, `emacs` and
`conda` layers key on tools that `mise install` provides, so their configs
arrive on the *next* apply. That is acceptable because all three are additive:
you get a plainer machine for one apply, not a broken one.

### root and libc are orthogonal

The most common mistake here, and one worth stating plainly: **not having root
does not mean you need static binaries.**

A no-root Ubuntu LTS box is glibc and runs ordinary release tarballs perfectly
well. It just cannot `apt install`. Only a genuinely musl host — Alpine, a
distroless image — restricts you to static builds. Conflating the two
over-restricts every Ubuntu deployment, which is the overwhelmingly common
case. They are separate facts and separate predicates.

### The arm64 musl gap

Upstream release matrices are not symmetric, and one gap bites here. As of
chezmoi 2.72.0:

| Target | Published artefact |
|---|---|
| linux amd64, glibc | `chezmoi-linux-amd64` (bare binary) |
| linux amd64, musl | `chezmoi-linux-amd64-musl` (bare binary) |
| linux arm64, either | `chezmoi_<v>_linux_arm64.tar.gz` only |

There is no musl-specific arm64 build. Alpine on a Graviton instance or a Pi
therefore has no purpose-built chezmoi; `bootstrap-standalone.sh` falls back to
the generic arm64 tarball and warns, because the alternative failure looks like
a corrupt download. mise does not have this gap — it publishes musl variants
for both architectures — which is why only the chezmoi step warns.

Both projects publish SHA256 checksums covering their bare binaries, and both
scripts verify before making anything executable.

## Testing

`scripts/layer-matrix.sh` resolves the layer set for machines you are not
sitting at, by feeding a synthetic context to the resolver in place of the real
one:

<!-- BEGIN GENERATED LAYER MATRIX -->
```
$ ./scripts/layer-matrix.sh
ubuntu-noroot          [debian, linux, mise, standalone]
ubuntu-noroot-tooled   [debian, linux, mise, rust, standalone]
ubuntu-root            [apt, debian, linux, mise, mise-full, root]
ubuntu-desktop         [apt, debian, desktop, emacs, linux, mise, mise-full, root, rust]
alpine-noroot          [linux, mise, standalone]
nixos-server           [linux, mise, mise-full, nix, root]
omarchy                [conda, desktop, emacs, linux, mise, mise-full, nix, omarchy, root, rust]
macbook                [conda, darwin, desktop, emacs, mise, mise-full, nix, nixdarwin, rust]
ci-container           [debian, linux, root]
```
<!-- END GENERATED LAYER MATRIX -->

The script compares each run with
[`scripts/layer-matrix.golden`](../scripts/layer-matrix.golden). Run
`./scripts/layer-matrix.sh --update` after an intentional change; it rewrites
the golden file and the generated block above.

This is the regression test for `layers.yaml`. A predicate that is subtly wrong
shows up as a machine gaining or losing a layer it should not have, which is
far cheaper to notice here than on the box itself.

The same mechanism answers what-if questions on a real machine. `layerProbes`
forces a binary to count as present or absent regardless of `PATH`:

```sh
chezmoi execute-template '{{ includeTemplate "layers.yaml.tmpl"
  (dict "chezmoi" .chezmoi "facts" .facts "layers" .layers
        "layerProbes" (dict "nix" true)) }}'
```

## Overrides

Detection cannot answer every question — whether a box you only reach over SSH
with X forwarding counts as a desktop, for instance. Two lists in
`~/.config/chezmoi/chezmoi.toml`, per-machine and untracked by design:

```toml
[data]
  layerForce = ["desktop"]
  layerDisable = ["conda"]
```

Both are applied inside the resolver's fixpoint loop, so a forced layer also
satisfies the `requires` of everything downstream, and a disabled one takes its
dependents with it.

## Known rough edges

- **`facts.root` means "can escalate without a password prompt."** `sudo -n` is
  the only probe safe to run unattended, so a Mac where sudo works fine but asks
  for a password reports `root = false`. Nothing depends on it there — the
  `nixdarwin` layer keys on `darwin-rebuild` being present, and that script only
  nags — but the name overpromises. Either rename it or accept the caveat.
- **Fixpoint iteration supports chains of up to four layers.** A fifth pass
  verifies that the result is stable, so deeper chains and non-converging
  conflicts fail explicitly. The deepest chain today is two.
- **`{{- /*` needs exactly one space after the trim marker.** Go's lexer checks
  for `/*` at a fixed offset, so an indented comment parses as a command and
  fails with `unexpected "/" in command`. Cost two debugging cycles; noted here
  so it costs zero next time.
