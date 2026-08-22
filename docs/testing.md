# Testing

## Implementation status

Order items 1 through 5 are implemented: predicate-key rejection, the asserted
layer matrix, declaration linting, sandbox applies, and shell checks.

The local regression suite is complete. The next implementation step is native
Linux sandbox applies in containers, which is order item 6 below.

This document began as the plan for testing the layer arrangement, written once
the resolver landed and reviewed twice before any of it was committed. It lives
in the repo so the reasoning outlives the branch that produced it.

Everything below was checked against chezmoi v2.70.5 from nixpkgs, on macOS,
branch `explore/layers`. Claims marked "verified" were run against the repo, and
the command is given so you can rerun them.

At the start of implementation, `./scripts/layer-matrix.sh` was the only test.
[layers.md](layers.md) describes the design being tested.

## Baseline before implementation

`scripts/layer-matrix.sh` feeds nine synthetic machine contexts to
`.chezmoitemplates/layers.yaml.tmpl` and prints the resolved layer set for each.
It ran clean at the outset and its output matched the table in
`docs/layers.md:187`.

That covers predicate evaluation, but the script does not assert its expected
output. Everything after resolution is untested:

| Stage | Covered |
|---|---|
| unknown predicate keys rejected | no, and they silently pass |
| predicate to active layer set | printed, not asserted |
| active set to managed paths through `.chezmoiignore` | no |
| `owns` and `scripts` declarations pointing at source entries | no |
| declaration schema and unique ownership | no |
| active templates rendering on each supported OS | no |
| `run_` scripts | no, `--dry-run` skips them |
| shell files under their intended interpreters | no |
| capability changes across applies | no |
| vim externals resolving | no |
| `bootstrap-standalone.sh` on a bare machine | no |

The tests below keep three claims separate:

1. The resolver chooses the expected layers.
2. Chezmoi turns those layers into the expected managed paths and renders them.
3. Installation scripts work on a real machine and can change later resolution.

Merging those claims into one test makes failures hard to diagnose and forces
every local check to pay for a container and the network.

## Step 0: reject unknown predicate keys in the resolver

Do this first, before any test code.

A layer whose only `detect` key is misspelled activates on every machine.
Verified:

```
detect: {ossRelease: omarchy}  ->  [typo]     # active everywhere
detect: {osRelease: omarchy}   ->  []         # correct
```

`.chezmoitemplates/layers.yaml.tmpl:96` starts each layer at
`$s := dict "ok" (not (empty $d))`. A non-empty `detect` map begins as passing,
and the passes that follow only read keys they recognize. Nothing rejects the
rest.

Fix it where it happens. This form renders correctly under the repo's template
engine:

```
{{ $known := list "os" "osRelease" "has" "hasAny" "fact" "requires" "conflicts" }}
{{ range keys $d }}{{ if not (has . $known) }}{{ fail ... }}{{ end }}{{ end }}
```

A lint over `.chezmoidata/layers.yaml` catches today's typos. The resolver guard
catches the ones added next year, including in a layer someone writes on a
branch that never runs the lint. Step 3 keeps the lint rule anyway, because a
lint failure names the file and the key while a template failure names neither.

## Step 1: make layer-matrix assert

Commit the full current output as `scripts/layer-matrix.golden`. The script
diffs against it and fails on any difference. Add `--update` to rewrite the
golden file when a change is intended. `--update` must always render the full
matrix, so a single-scenario invocation cannot replace the golden file with one
row.

Keep the golden file beside the script. There is no test tree today, and one
expected-output file is easiest to find next to what produces it.

The scenario table in `docs/layers.md:187` is a second copy of the same data and
will rot. Do not write a markdown table parser to compare them. Either wrap the
table in generated-content markers and have `--update` rewrite it, or delete the
table and link to the golden file. The marker approach keeps the doc readable
and costs a few lines of `sed`.

## Step 2: sandbox applies

This covers the gap between a correct layer set and the paths chezmoi actually
manages. It is fast enough to run on every check. Verified working: the command
below produced 86 managed entries in a few seconds.

`scripts/check-layer-applies.sh` creates the destination first and isolates
every writable chezmoi path:

```sh
mkdir -p "$T/home" "$T/cache"

chezmoi apply \
  -D "$T/home" \
  -c "$T/chezmoi.toml" \
  -S "$PWD" \
  --cache "$T/cache" \
  --persistent-state "$T/state.boltdb" \
  --exclude=scripts,externals \
  --force \
  --refresh-externals=never
```

`$T/chezmoi.toml` holds `sourceDir`, a `[data.facts]` block, and a
`[data.layerProbes]` map, built from the same scenario definitions as
`layer-matrix.sh`.

Every `apply`, `managed`, and `status` call must repeat the same `-D`, `-c`,
`-S`, `--cache`, `--persistent-state`, and data flags. Apply and status exclude
scripts and externals. A read-only `managed` inspection may swap that filter for
`--include=scripts` but must keep the rest of the context. Otherwise an
assertion silently reads the real home or the real state.

For each applicable scenario, assert:

- Every source-backed `owns` path for an active layer is managed.
- Every source-backed `owns` path for an inactive layer is absent.
- `chezmoi managed --include=scripts` lists the scripts of active layers and
  omits the rest. Verified: in a standalone-plus-mise sandbox this returns
  `fetch-portable-tools.sh` and `mise-install.sh`, and correctly omits the doom,
  rust, and darwin-rebuild scripts.
- Representative rendered values are correct, including the pinned mise version
  and the OS-specific branches.
- `chezmoi status` is empty immediately after the apply.

Assert on layer-owned paths only. Do not snapshot the whole home, or adding one
unrelated base dotfile will mean editing every scenario.

One apply reaches the deterministic target state for a fixed context, so do not
apply twice here. Verified: the tree contains no `modify_`, `create_`, or
`symlink_` entries, and with scripts excluded and `layerProbes` fixed there is
nothing left for a second pass to change. The real two-pass capability case is
in step 5.

Three limits to state plainly:

- `.chezmoi.os` and `.chezmoi.osRelease` come from the host. A macOS run covers
  Darwin branches only. The same runner in Linux containers covers the rest.
- `layerProbes` overrides resolver probes, but other templates call `lookPath`
  against the real PATH. This reaches content files, not only script comments:
  `dot_cargo/config.toml.tmpl:6` branches on sccache and
  `dot_config/git/config.tmpl:43` on git-lfs. The run only represents a
  synthetic machine if the runner also constrains PATH.
- Comparing applied file sets cannot prove unique ownership. Two layers can
  claim one path and still produce a correct-looking home. Step 3 checks the
  declarations themselves.

## Step 3: lint the declarations

Emit lint records from `.chezmoidata/layers.yaml` with a chezmoi template, so the
checker stays POSIX shell and adds no YAML parser.

Schema first:

- A layer may contain only `detect`, `implies`, `owns`, `scripts`, and `planned`.
- `detect` may contain only `os`, `osRelease`, `has`, `hasAny`, `fact`,
  `requires`, and `conflicts`. This repeats step 0 on purpose. The lint names the
  offending layer and key, which a template failure does not.
- Fact names and OS values must come from the supported sets.
- Every name in `requires`, `conflicts`, and `implies` must be a real layer.

Then ownership:

- Every `owns` declaration resolves to at least one real source entry.
- Every `scripts` declaration matches at least one `run_` source entry once
  chezmoi strips the attribute prefix.
- No two layers claim the same path or script.
- No two declarations overlap as parent and child. An inactive owner of
  `.config/foo` hides an active owner's `.config/foo/bar`, because ignoring a
  directory ignores everything under it.

The `omarchy` declarations are planned content, not typos. Mark that with
`planned` in `.chezmoidata/layers.yaml` rather than keeping an allowlist inside
the test. The lint reports planned missing entries without failing. Missing
entries anywhere else fail. Drop the marker when the source files land.

## Step 4: test each shell with the right interpreter

`sh -lc exit` is not a dotfile test. It reads neither `.bashrc` nor `.zshenv`, so
it only proves the container has a working shell.

Run `dash -n` and `shellcheck -s sh` over the files that claim POSIX syntax:

- `bootstrap-standalone.sh`
- a rendered `run_onchange_after_fetch-portable-tools.sh`
- the rendered `shell-env.sh`, `shell-path.sh`, and `shell-interactive.sh` bodies

Do not lint `.bashrc` as POSIX sh. It uses `shopt` at `dot_bashrc.tmpl:25` and
`:29`, and `dot_zshrc.tmpl` uses `autoload` and zsh glob qualifiers, so a POSIX
lint reports correct code as broken. Check rendered Bash with `bash -n` and then
start an isolated interactive Bash against the sandbox home. Check rendered zsh
with `zsh -n` and start zsh with the sandbox as `ZDOTDIR`.

Alpine in step 5 supplies BusyBox `ash` for parsing and running the POSIX
bootstrap path. That complements local dash without pretending ash reads Bash or
zsh startup files.

## Step 5: containers for native Linux and for installation

Docker is installed here through Rancher Desktop. The daemon was stopped when
this was written.

### Native Linux sandbox applies

Run the step 2 runner, scripts and externals still excluded, in Ubuntu and
Alpine images. This supplies real `.chezmoi.os` and `.chezmoi.osRelease` values
and stays offline once the image exists.

One Ubuntu image covers `ubuntu-noroot`, `ubuntu-noroot-tooled`, `ubuntu-root`,
and `ubuntu-desktop` by varying facts and `layerProbes`. Alpine covers
`alpine-noroot`.

`ci-container` stays resolver-only. Running it natively would mean forcing
`apt-get` to look absent inside an image that ships it, which describes no real
machine. The only new input a native run would add is the os-release file, and
`layer-matrix.sh` already covers that.

Before each apply, print and assert the effective UID, the os-release values, and
the full probe inventory. A run must not claim to represent a matrix row unless
those inputs match the row. NixOS and Omarchy stay resolver-only until they have
source-backed content worth the cost.

### End-to-end standalone bootstrap

These run under the explicit slow mode, because `chezmoi init --apply` also runs
the `mise-install` hook and that hook runs a full `mise install`.

Run `bootstrap-standalone.sh` only in unprivileged images where the standalone
layer should activate:

- Ubuntu without git, amd64
- Alpine without git, amd64
- Alpine without git, arm64, with an explicit `--platform=linux/arm64`

The arm64 musl gap is in the chezmoi download inside `bootstrap-standalone.sh`.
mise publishes an arm64 musl binary, so only the chezmoi step needs the fallback.

The bootstrap has to test the code under review. Today it cannot:
`bootstrap-standalone.sh:27` hardcodes `REPO_HTTPS` and line 203 clones with no
ref, so a container silently tests `main` on GitHub while claiming to test this
branch. Add an injectable repository URL and ref for the runner, leave the
production default alone, and point the container at the current commit. Keep one
separate smoke test against the real GitHub URL to exercise the git-less
built-in clone.

For the current-code cases, assert:

- the resolved layer set matches the scenario;
- `.config/mise/conf.d/20-standalone.toml` exists and `10-dotfiles.toml` does not;
- `~/.local/bin/mise` exists, is executable, and runs;
- a fresh process with `~/.local/bin` on PATH can apply again.

Do not assert on the contents of the persistent state file. mise existing and
running already proves the hook ran.

Test capability convergence on its own, away from the fixed-context sandbox.
Start with a capability absent, apply, put a controlled executable on the next
process's PATH, apply again, and assert the newly active layer's files appear.
That exercises the documented second-apply behaviour without downloading the full
mise tool list.

### Network mode

Network work stays out of the default check. An explicit `--network` mode covers:

- the portable-tool fetch, rendered and run in a focused fixture rather than
  through the full mise tool list;
- the five pinned vim externals in
  `dot_vim/pack/plugins/start/.chezmoiexternal.toml.tmpl`. Every other step
  passes `--exclude=externals`, so a dead tarball URL or a wrong `include`
  pattern currently surfaces only on a real apply on a real machine.

The end-to-end bootstrap, the Doom clone, and a full `mise install` run only
under `--slow`. Those are deliberate smoke tests, not pre-commit requirements.

macOS cannot be containerized. Darwin coverage stays the step 2 sandbox,
`nix flake check`, and `darwin-rebuild build --dry-run`.

## What to skip

Do not commit snapshots of every rendered dotfile. They churn, and they bury the
layer assertions under unrelated content changes. Assert layer-owned paths and a
small set of rendered values.

Do not put network containers in a pre-commit hook. A hook people skip is not a
test runner.

## Entry points

`scripts/check-layers.sh` runs steps 1 through 4. Fast, offline, and no
dependency the repo does not already declare. A pre-commit hook may call it, and
it stays usable on its own.

`scripts/check-layer-containers.sh` runs step 5. Default mode runs the native
Linux sandbox checks. `--network` runs the portable fetch and the vim externals.
`--slow` runs bootstrap and the heavy hooks. If CI arrives later, run the offline
script on every change and schedule the others.

## Order

1. Fix the resolver to reject unknown predicate keys.
2. Add the matrix golden file and regenerate the doc table from it.
3. Add the declaration and ownership lint.
4. Add the macOS sandbox apply runner.
5. Add interpreter-specific shell checks and the offline entry point.
6. Reuse the sandbox runner in native Linux containers.
7. Add bootstrap containers once the repository override exists.

Steps 1 through 5 are the local regression suite. Containers add OS and
installation coverage without becoming the only way to test layer dispatch.
