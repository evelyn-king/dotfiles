# Agent 4 deployment review: macOS package and runtime ownership

Reviewed commit: `abb2e562c5f61d4904a636fe1645863a4feb7722`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-03

Local review host: macOS 26.6.2 (build 25G83), Apple Silicon arm64, account
`evelynking`, Determinate Nix 3.11.3, nix-darwin 26.11.4cff07d, mise 2026.8.3,
chezmoi 2.70.5, no Homebrew installed

The Linux half of this workstream reviewed `30923db`. The two commits differ
only in `docs/`, so every package and runtime declaration examined here is
byte-identical to the one that report reviewed.

## Scope

This is the macOS and nix-darwin half of Agent 4's package and runtime
ownership workstream. I reviewed:

- `nix/flake.nix` and the flake's evaluated outputs
- `dot_config/mise/conf.d/10-dotfiles.toml`
- `dot_config/mise/mise.lock`
- `run_onchange_after_mise-install.sh.tmpl` and the macOS `mup` alias
- `run_after_darwin-rebuild.sh.tmpl` as a consumer of the package declaration
- Doom's pinned checkout and the six Vim externals
- `docs/package-lists/macos.md`, `docs/package-lists/mise.md`, and the package
  sections of `README.md`
- the running nix-darwin generation and the live mise installation

I did not review `.chezmoidata/packages.yaml`, pacman, the AUR, or Omarchy.
The Linux report covers those. I also left flake input freshness, AeroSpace,
and per-cask Apple Silicon behavior to Agent 2, whose report does not yet
exist.

## Workstream verdict

macOS is blocked. Not "blocked pending a manual step" but blocked at the first
command the documentation gives you.

`nix/flake.nix` declares `terraform`, which nixpkgs marks unfree, and the flake
never sets `allowUnfree`. `darwin-rebuild switch --flake <src>/nix#macbook`
refuses to evaluate. There is no first generation, so there are no Nix
packages, no `mise`, no `bun`, no `uv`, and no Homebrew casks. I reproduced
this on the review host against the reviewed commit.

The same evaluation failure disables the nix-darwin drift hook, which swallows
the error and reports that it is skipping the check. So the one mechanism the
repo has for telling you the system is out of date goes quiet exactly when the
system has never been built.

Behind that blocker sit two more problems in the same layer, and fixing the
license would leave both untouched.

Nothing installs Homebrew, and nix-darwin treats its absence as a warning
rather than an error. On a Mac without `brew`, `darwin-rebuild switch` prints
one red line and exits successfully having installed none of the 21 casks.
That includes Ghostty and AeroSpace, two applications this repo spends real
configuration on. The review host is itself in that state.

The Brewfile runs under `sudo --user=evelyn`, a literal string in the flake.
The account on this machine is `evelynking`. Every cask install and every cask
removal is addressed to a user who does not exist here.

There is also a fourth problem at that level, which only bites a Mac that has
been used before. `cleanup = "uninstall"` renders as
`brew bundle --force-cleanup`, and the Brewfile declares no formulae at all, so
every switch uninstalls every Homebrew formula on the machine.

Below that sit seven ownership issues worth fixing that do not stop a
deployment. macOS installs its mise tools with no lockfile at all, because the
committed lock carries `linux-x64` keys only. `pkgs.gcc` puts `cc`, `ld`, `as`
and eleven more toolchain commands ahead of the Xcode Command Line Tools for
every shell this repo configures. The mise hook aborts the whole apply if
`bun` or `uv` is missing. `~/.local/bin` outranks the Nix profile and macOS has
no check for what hides there. `mise self-update`, which the README recommends
without qualification, cannot work when Nix owns the binary. Intel Macs are
unsupported and nothing says so. And `greedyCasks` contradicts the reason
`macos.md` gives for using casks in the first place.

One result is genuinely clean, and worth saying plainly because the Linux side
was not. Nix, Homebrew and mise do not fight over a single command name.
Comparing all 345 commands the flake installs against the 75 mise shims and the
seven cask binaries produced an empty intersection three times over. The
"anything managed by mise is deliberately not here" comment in the flake is
accurate.

## macOS ownership matrix

`chezmoi apply` installs no system packages on macOS. It manages the mise
declaration, runs the mise install hook, runs the Doom hook, fetches the Vim
externals, and nags about nix-darwin drift. Every Nix package and every
Homebrew cask waits on a separate, manual `sudo darwin-rebuild switch`.

`chezmoi ignored` confirms the boundary: `nix` and `.config/mise/mise.lock` are
repo content and never reach `$HOME`. On macOS the ignore list also drops
`install-omarchy-packages.sh` and `linux-package-drift.sh`.

### Nix system packages

The flake's `environment.systemPackages` evaluates to 73 derivations. Eleven
come from nix-darwin itself (`zsh`, `bash-interactive`, `nix-zsh-completions`,
`texinfo-interactive`, and the seven `darwin-*` helpers). The other 62 are the
repo's own declarations, listed here with the commands they put in
`/run/current-system/sw/bin`.

| Declaration | Installed commands | Notes |
| --- | --- | --- |
| `atuin` | `atuin`, `atuin-server` | Sync account is manual |
| `direnv` | `direnv` | Shell integration is repo-managed |
| `keychain` | `keychain` | SSH key material stays manual |
| `starship` | `starship` | Shell integration is repo-managed |
| `tmux` | `tmux` | |
| `zellij` | `zellij` | |
| `zoxide` | `zoxide` | Shell integration is repo-managed |
| `ast-grep` | `ast-grep` | |
| `bat` | `bat` | |
| `dust` | `dust` | |
| `duf` | `duf` | |
| `eza` | `eza`, `exa` | |
| `fd` | `fd` | |
| `fzf` | `fzf`, `fzf-tmux`, `fzf-share` | |
| `jq` | `jq` | Shadows `/usr/bin/jq` |
| `ripgrep` | `rg` | Used by Vim and shell helpers |
| `tealdeer` | `tldr` | No conflicting client on macOS, unlike Omarchy |
| `delta` | `delta` | Used by Git configuration |
| `git` | `git` plus 10 helpers | Shadows the Xcode CLT `git` |
| `git-lfs` | `git-lfs` | Needs `git lfs install` once per account |
| `lazygit` | `lazygit` | |
| `bun` | `bun`, `bunx` | Backend for mise npm installs |
| `luarocks` | `luarocks`, `luarocks-admin` | |
| `lua-language-server` | `lua-language-server` | |
| `mise` | `mise` | Owns every runtime and global CLI tool |
| `pixi` | `pixi` | |
| `uv` | `uv`, `uvx` | Backend for mise pipx installs |
| `emacs-macport` | `emacs`, `emacsclient`, `ctags`, `etags`, `ebrowse` | Enables the Doom hook; `ctags` shadows `/usr/bin/ctags` |
| `neovim` | `nvim` | |
| `vim` | `vim`, `vi`, `view`, `vimdiff`, `vimtutor`, `ex`, `rvim`, `rview` | Plugins come from chezmoi externals |
| `btop` | `btop` | |
| `htop` | `htop` | |
| `hyperfine` | `hyperfine` | |
| `pv` | `pv` | |
| `cmake` | `cmake`, `ctest`, `cpack` | |
| `coreutils` | 107 GNU commands, unprefixed | Replaces 55 BSD commands including `stat`, `readlink`, `install` and `sort` |
| `gawk` | `awk`, `gawk` | Replaces BSD awk |
| `gcc` | `cc`, `c++`, `cpp`, `gcc`, `g++`, `ld`, `as`, `ar`, `ranlib`, `nm`, `objdump`, `objcopy`, `strip`, `size`, `strings`, `addr2line`, `c++filt`, `gprof` | Replaces the Xcode CLT toolchain. See A4M-006 |
| `graphicsmagick` | `gm` and three `-config` scripts | |
| `graphviz` | `dot` and roughly 30 layout tools | |
| `libxml2` | `xmllint`, `xmlcatalog` | Shadows `/usr/bin/xmllint` |
| `pkgconf` | `pkgconf` | No `pkg-config` alias. See notes below |
| `portaudio` | none | Library only |
| `sccache` | `sccache` | Remote cache setup is manual |
| `shellcheck` | `shellcheck` | |
| `sqlite` | `sqlite3` | Shadows `/usr/bin/sqlite3` |
| `aspellWithDicts [en]` | `aspell` and helpers | A local buildEnv, so it is not in the binary cache |
| `llama-cpp` | `llama-*` binaries and Metal backends | Models are a manual download |
| `pandoc` | `pandoc`, `pandoc-server` | No TeX engine from Nix; `basictex` is a cask |
| `poppler-utils` | `pdftotext` and 11 more | |
| `tesseract` | `tesseract` | Extra language data is manual |
| `chezmoi` | `chezmoi` | Cannot bootstrap itself. See A4M-008 |
| `cloudflared` | `cloudflared` | Tunnel login is manual |
| `gnupg` | `gpg`, `gpg-agent` and 25 more | Secret-key import stays manual |
| `google-cloud-sdk` | `gcloud`, `gsutil`, `bq`, two credential helpers | `gcloud auth login` is manual |
| `lima` | `limactl`, `docker.lima`, `nerdctl.lima`, `kubectl.lima` | Suffixed names only, so no clash with Rancher Desktop's `docker` |
| `pinentry_mac` | `pinentry-mac` | Does not provide a bare `pinentry`; Agent 7 should confirm what the GPG config asks for |
| `prettyping` | `prettyping` | |
| `sshpass` | `sshpass` | |
| `terraform` | none reachable | Unfree. Blocks the whole evaluation. See A4M-001 |
| `w3m` | `w3m`, `w3mman` | |
| `wget` | `wget` | |

`fonts.packages` adds three Nerd Font families outside `systemPackages`.

Two gaps are worth recording even though neither is a finding on its own.
`pkgconf` installs under that name and nothing provides `pkg-config`, which is
the name build systems actually probe for, and macOS has no `/usr/bin/pkg-config`
either. And the flake declares `cmake` but no `make`, so native builds fall
back to the Xcode CLT `/usr/bin/make`, which the repo never lists as a
prerequisite.

### Homebrew casks

21 casks, one tap, zero formulae, zero Mac App Store apps. I fetched every
cask's current metadata from the Homebrew API on 2026-09-03. All 20 in the core
repository resolved. `nikitabobko/tap/aerospace` comes from a tap and has no
API record, so Agent 2 should confirm it against the tap itself.

| Cask | Installs | Commands added to PATH | Notes |
| --- | --- | --- | --- |
| `1password-cli` | binary only | `op` | Account sign-in is manual |
| `adobe-acrobat-reader` | `.pkg` | none | Privileged installer, self-updates |
| `nikitabobko/tap/aerospace` | `AeroSpace.app` | `aerospace` | Needs Accessibility approval; Agent 2 owns startup behavior |
| `basictex` | `.pkg` | `pdflatex`, `tlmgr` and the rest, via `/Library/TeX/texbin` | Privileged installer. The commands arrive through `path_helper`, not through this repo's PATH list |
| `bitwarden` | `Bitwarden.app` | none | Login and unlock are manual, self-updates |
| `chatgpt` | `ChatGPT.app` | none | Sign-in is manual, self-updates |
| `claude` | `Claude.app` | none | The desktop app. The `claude` CLI is a separate mise tool. Self-updates |
| `firefox` | `Firefox.app` | none | Self-updates |
| `ghostty` | `Ghostty.app` | none, plus man pages | The terminal this repo configures. Self-updates |
| `gimp` | `GIMP.app` | none | |
| `iterm2` | `iTerm.app` | none | Self-updates |
| `klayout` | suite | none | Installed as an app suite |
| `ltspice` | `.pkg` | none | Privileged installer, requires macOS 14 or newer |
| `obsidian` | `Obsidian.app` | `obsidian` | Self-updates. See the PATH note below |
| `paraview` | `ParaView-6.1.1.app` | `paraview` | Bundles its own Python 3.12 and MPI build |
| `rancher` | `Rancher Desktop.app` | `docker`, `kubectl`, `nerdctl` and more in `~/.rd/bin` after first run | Those commands come from the app at runtime, not from the cask |
| `raycast` | `Raycast.app` | none | Declares `arch: arm64`. Self-updates |
| `spotify` | `Spotify.app` | none | Self-updates |
| `visual-studio-code` | `Visual Studio Code.app` | `code`, `code-tunnel` | Onboarding is manual, self-updates |
| `zed` | `Zed.app` | `zed` | Onboarding is manual, self-updates |
| `zotero` | `Zotero.app` | none | Self-updates |

Twelve of the 21 report `auto_updates: true`. The flake sets
`greedyCasks = true` and `onActivation.upgrade = true`, which overrides those
updaters. See A4M-011.

`shell-path.sh` also appends `/Applications/Obsidian.app/Contents/MacOS` on
darwin, below the inherited PATH. The Obsidian cask already links an `obsidian`
command into `/opt/homebrew/bin`, which ranks higher, so the explicit entry
only ever exposes the raw `Obsidian` app binary. It is redundant once the cask
installs.

### mise declarations and lock entries

The declaration holds 28 tools. There is no macOS lock. `mise.lock` is
`linux-x64` only, and the macOS branch of the install hook runs a bare
`mise install`.

I ran `mise lock --global --platform macos-arm64 --dry-run` against the repo
config. All 28 tools resolved for `macos-arm64`, at exactly the versions the
committed Linux lock records. So the missing macOS lock is a choice, not a
platform limitation, and adding it would not move a single version.

| Tool declaration | Version resolved for `macos-arm64` | Backend | Primary command |
| --- | --- | --- | --- |
| `node = 26.8.0` | 26.8.0 | `core:node` | `node`, `npm`, `npx` |
| `python = 3.14.7` | 3.14.7 | `core:python` | `python`, `python3`, `pip` |
| `go = 1.27.0` | 1.27.0 | `core:go` | `go`, `gofmt` |
| `rust = stable` | `stable` | `core:rust` | `rustc`, `cargo`, rustup proxies |
| `claude = latest` | 2.1.258 | `aqua:anthropics/claude-code` | `claude` |
| `codex = latest` | 0.152.1 | `aqua:openai/codex` | `codex` |
| `opencode = latest` | 1.18.26 | `aqua:anomalyco/opencode` | `opencode` |
| `pi = latest` | 0.84.4 | `aqua:earendil-works/pi` | `pi` |
| `npm:@google/gemini-cli = latest` | 0.58.0 | npm | `gemini` |
| `npm:@just-every/code = latest` | 0.6.177 | npm | `coder` |
| `pipx:black = 26.5.1` | 26.5.1 | pipx | `black`, `blackd` |
| `pipx:conda-lock = 4.0.2` | 4.0.2 | pipx | `conda-lock` |
| `pipx:conda-package-handling = 2.5.0` | 2.5.0 | pipx | `cph` |
| `pipx:docling-slim = 2.123.0` | 2.123.0 | pipx | `docling` and related |
| `pipx:markdown-code-runner = 2.7.0` | 2.7.0 | pipx | `markdown-code-runner` |
| `pipx:mypy = 2.3.1` | 2.3.1 | pipx | `mypy`, `dmypy`, `stubgen` |
| `pipx:poethepoet = 0.48.0` | 0.48.0 | pipx | `poe` |
| `pipx:ruff = 0.16.4` | 0.16.4 | pipx | `ruff` |
| `pipx:tuitorial = 0.16.0` | 0.16.0 | pipx | `tuitorial` |
| `pipx:unidep = 3.4.2` | 3.4.2 | pipx | `unidep` |
| `pipx:pre-commit = 4.6.2` | 4.6.2 | pipx | `pre-commit` |
| `npm:@doist/todoist-cli = 4.0.0` | 4.0.0 | npm | `td` |
| `npm:@googleworkspace/cli = 0.22.5` | 0.22.5 | npm | `gws` |
| `npm:tree-sitter-cli = 0.26.13` | 0.26.13 | npm | `tree-sitter` |
| `gh = latest` | 2.99.0 | `aqua:cli/cli` | `gh` |
| `herdr = 0.8.2` | 0.8.2 | `aqua:herdrdev/herdr` | `herdr` |
| `usage = latest` | 6.6.1 | `aqua:jdx/usage` | `usage` |
| `micromamba = 2.9.0-0` | 2.9.0-0 | `github:mamba-org/micromamba-releases` | `micromamba` |

Three of the four ownership overlaps the Linux report found do not exist here.
`herdr`, `usage` and `tree-sitter` have no macOS system package competing with
them, so mise is their sole owner and nothing shadows anything.

`micromamba` is also a single owner. `~/.local/opt/micromamba` on the review
host is only the root prefix that `shell-env.sh` sets, and the interactive
shell resolves the binary with `mise which` before falling back to PATH.

### Doom and Vim ownership

Identical to Linux. Both are platform-independent chezmoi mechanisms.

| Component | Owner | Pinning and update behavior |
| --- | --- | --- |
| Doom core | `run_onchange_after_install-doom-emacs.sh.tmpl` | Detached checkout at `1404f1bac5a2ae8602b4d861f7805e194c05d28c`; refuses to move a dirty checkout |
| Doom packages | Doom's own installer | `doom install --aot --no-config --env` reruns when the core revision or managed config changes |
| Vim gruvbox | chezmoi archive external | Commit `697c00291db857ca0af00ec154e5bd514a79191f` |
| Vim nerdcommenter | chezmoi archive external | Commit `a462bbda1e26f44fb3d3eb9d9d1c6a07aa98e665` |
| Vim nerdtree | chezmoi archive external | Commit `690d061b591525890f1471c6675bcb5bdc8cdff9` |
| Vim airline | chezmoi archive external | Commit `192c2c7e8e58fcc771b1959e633b963984319a7c` |
| Vim fugitive | chezmoi archive external | Commit `3b753cf8c6a4dcde6edee8827d464ba9b8c4a6f0` |
| Vim surround | chezmoi archive external | Commit `3d188ed2113431cf8dac77be61b842acb64433d9` |

The rendered external file parses as TOML and declares six revision-pinned
archives with no checksums. Agent 1 owns that lifecycle, so I am not repeating
it as an Agent 4 finding.

The Doom hook renders `lookPath` for both `git` and `emacs` into its comment
header, so it reruns once Nix supplies Emacs. That is the right pattern and it
works. The macOS wrinkle is only that Emacs arrives from a separate
`darwin-rebuild switch` rather than from within an apply, so the retry needs a
third apply rather than a second.

## Command ownership: overlap analysis

I listed the contents of `bin` for all 73 flake derivations from
`cache.nixos.org`, which gives 345 distinct commands, and compared that set
against the 75 mise shims on the review host and the seven commands the casks
add.

| Comparison | Overlapping commands |
| --- | --- |
| Nix and mise | none |
| Nix and Homebrew casks | none |
| mise and Homebrew casks | none |
| mise and `/usr/bin` | `python3`, `pip3` |
| Nix and `/usr/bin` | 90 |
| Nix and `/bin` | 27 |

The mise pair is deliberate and documented. mise owns the user's Python and
macOS keeps its own for system scripts.

The 117 Nix commands that outrank `/usr/bin` and `/bin` are the part worth
attention. `shell-path.sh` puts `/run/current-system/sw/bin` above the
inherited PATH, so this is not theoretical. Most of the 117 are harmless GNU
replacements, and `sh`, `bash` and `zsh` come from nix-darwin's own defaults
rather than from this repo. Two groups are worth a second look.

- The toolchain from `pkgs.gcc`: `cc`, `c++`, `cpp`, `ld`, `as`, `ar`,
  `ranlib`, `nm`, `objdump`, `strip`, `size`, `strings`, `addr2line` and
  `c++filt`. Covered in A4M-006.
- The 79 GNU coreutils commands that share a name with a BSD one, 55 of them
  against `/usr/bin` and 24 against `/bin`. They include `stat`, `readlink`,
  `install`, `ls`, `cp`, `rm`, `date`, `df` and `sort`, and argument syntax
  differs from the BSD versions for several. Preferring GNU tools on a Nix Mac
  is a defensible choice, but the repo never writes it down, and Agent 5 should
  confirm no repo script depends on BSD behavior.

## Manual state after package installation

Installing the packages does not finish these tools.

| Tool group | Remaining manual state |
| --- | --- |
| Homebrew itself | Full installation, before the first `darwin-rebuild switch`. See A4M-002 |
| Xcode Command Line Tools | Required for `/usr/bin/make` and for Determinate Nix's installer |
| 1Password, Bitwarden | Sign-in and unlock |
| Google Cloud SDK | `gcloud auth login` and application-default credentials |
| GitHub CLI | `gh auth login` |
| Claude, Codex, Gemini, OpenCode, Pi, Coder | Provider authentication and onboarding |
| Todoist and Google Workspace CLIs | Account authentication |
| Rancher Desktop | First run creates `~/.rd/bin`; container runtime initialization |
| Cloudflared | Tunnel login |
| llama.cpp, Tesseract | Model and language-data downloads |
| BasicTeX | `tlmgr` package installation for anything past the base set |
| AeroSpace, Raycast | Accessibility approval and login items, owned by Agent 2 |
| Doom | A third apply on macOS, because Emacs arrives from a separate `darwin-rebuild switch` |
| micromamba | Environment creation, owned by Agent 6 |

## Findings

### A4M-001

Finding ID: A4M-001

Severity: blocker

Platform and scenario: Any Apple Silicon macOS host, fresh or existing

Deployment phase: First nix-darwin activation, and every later drift check

Files and lines: `nix/flake.nix:106` (`terraform` in `environment.systemPackages`),
`nix/flake.nix:21-26` (no `nixpkgs.config.allowUnfree` anywhere in the file),
`run_after_darwin-rebuild.sh.tmpl:14,20-31`, `docs/package-lists/macos.md:10-14`

Observed behavior: nixpkgs marks `terraform` unfree under BUSL 1.1. The flake
sets neither `nixpkgs.config.allowUnfree` nor an `allowUnfreePredicate`.
Evaluating anything that needs the package's `outPath` fails. Because flakes
evaluate purely, `~/.config/nixpkgs/config.nix` cannot rescue it either.

Fresh-host consequence: `darwin-rebuild switch --flake <src>/nix#macbook`, the
command in `docs/package-lists/macos.md` and behind the `nix-switch` alias,
aborts. No generation is built, so the host gets no `mise`, `bun`, `uv`, `git`,
`chezmoi`, `emacs`, or Homebrew integration. Separately, the drift hook
evaluates `cfg.system.path.outPath`, hits the same error, discards it with
`2>/dev/null`, and prints "cannot evaluate; skipping the drift check". The
warning system stays silent about a system that was never built.

Reproduction or evidence: On the review host at the reviewed commit,
`nix build --dry-run --no-link .#darwinConfigurations.macbook.system` returned
`error: Refusing to evaluate package 'terraform-1.15.9' ... because it has an
unfree license ('bsl11')`. Rerunning with `NIXPKGS_ALLOW_UNFREE=1 --impure`
completed the dry run with no other failure, so `terraform` is the only
evaluation blocker in the flake. Running the drift hook's own eval expression
without the variable failed, which is the branch that prints the skip message.
`/run/current-system/sw/bin/terraform` does not exist, and the running
generation has no Homebrew activation, so this configuration has never been
activated on this machine.

Automated or manual: Automated failure with no documented recovery

Current workaround: `sudo NIXPKGS_ALLOW_UNFREE=1 darwin-rebuild switch --impure
--flake <src>/nix#macbook`, which also makes the whole evaluation impure.

Recommended change: Decide whether Terraform is wanted. If it is, add
`nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
"terraform" ];` so the exception is named and reviewable, rather than a blanket
`allowUnfree`. If it is not, drop the package. Either way, make the drift hook
distinguish "the flake does not evaluate" from "no `darwin-rebuild` on PATH"
instead of exiting 0 on both.

Verification: On a stock Apple Silicon host, run the documented switch command
with no environment variables and require a first generation. Then run
`chezmoi apply` and require the drift hook to stay quiet, and run it again
against a deliberately edited flake and require the nag.

Confidence: verified

### A4M-002

Finding ID: A4M-002

Severity: high

Platform and scenario: Apple Silicon macOS with no Homebrew, which is every
stock Mac

Deployment phase: First nix-darwin activation

Files and lines: `nix/flake.nix:114-115`, `docs/package-lists/macos.md:29-32`,
`README.md:29-33`

Observed behavior: `homebrew.enable = true` makes nix-darwin write a Brewfile
and add an activation step, but nix-darwin never installs Homebrew. The
generated activation script tests for `/opt/homebrew/bin/brew` and, when it is
missing, prints a red "Homebrew is not installed, skipping..." to stderr and
continues. Activation succeeds. Nothing in the repo installs Homebrew and no
document tells you to. `docs/package-lists/macos.md` mentions the requirement
in a trailing half-sentence and the README's ownership table does not mention
it at all.

Fresh-host consequence: The first switch reports success while installing none
of the 21 casks. The user gets a working CLI environment and no Ghostty, no
AeroSpace, no editor apps, no password manager. Both missing applications have
managed configuration in this repo, so the configuration lands with nothing to
configure. The message scrolls past in the middle of activation output and
carries no non-zero exit status.

Reproduction or evidence: The review host has no `/opt/homebrew` and no
`/usr/local/bin/brew`. Evaluating
`config.system.activationScripts.homebrew.text` from the reviewed flake yields
exactly the `if [ -f "/opt/homebrew/bin/brew" ] ... else echo error ... fi`
shape described above. The running generation's `activate` script contains no
`brew bundle` step at all, confirming this repo's Homebrew integration has
never run here.

Automated or manual: Undocumented manual prerequisite with a silent automated
failure

Current workaround: Install Homebrew from `https://brew.sh` before the first
`darwin-rebuild switch`.

Recommended change: Put Homebrew in the macOS bootstrap sequence alongside the
Xcode Command Line Tools, Determinate Nix and chezmoi, and say so in the README
ownership table rather than only in `macos.md`. If a silent skip is not
acceptable, add a preflight assertion in the flake so a missing `brew` fails
activation instead of warning.

Verification: On a stock Mac, run the documented bootstrap and require all 21
casks present after the first switch. Then repeat with Homebrew deliberately
absent and require the run to fail loudly rather than succeed.

Confidence: verified

### A4M-003

Finding ID: A4M-003

Severity: high

Platform and scenario: Any Apple Silicon macOS host whose short account name is
not `evelyn`, including the review host

Deployment phase: First nix-darwin activation and every later switch

Files and lines: `nix/flake.nix:18` (`username = "evelyn"`),
`nix/flake.nix:26` (`system.primaryUser = username`),
`docs/package-lists/macos.md:34-35`

Observed behavior: The Homebrew activation step runs
`sudo --preserve-env=PATH --user=evelyn --set-home env brew bundle --file=...
--force-cleanup`. The user name is baked into the generated script from the
flake's `username` binding. `chezmoi data` reports `username = evelynking` on
this machine, and `id -un` agrees.

Fresh-host consequence: Every cask install and every cask removal is addressed
to an account that does not exist, so `sudo` fails before `brew bundle` runs.
The repo already knows this class of problem exists, since `macos.md` states
that `system.primaryUser` must match `id -un` or activation fails, but the
value is a literal rather than something derived or asserted.

Reproduction or evidence: The activation text quoted above came from evaluating
the reviewed flake on this host. `id -un` returns `evelynking`. The plan's own
macOS protocol calls for a negative test with a short username other than
`evelyn`, so this was an anticipated risk; it turns out to be the maintainer's
own machine.

Automated or manual: Automated failure

Current workaround: Rename the account, or edit `username` in the flake before
the first switch.

Recommended change: This is the package-installation half of a broader problem.
Agent 2 owns the general question of the hardcoded username, architecture and
configuration name, and the coordinator should merge this entry into that
finding. From the ownership side the requirement is only that cask installs run
as the invoking account.

Verification: Activate on a host whose short name is not `evelyn` and require
the cask set to install. Repeat the cold-start protocol under the negative-test
account the plan already calls for.

Confidence: verified

### A4M-004

Finding ID: A4M-004

Severity: high

Platform and scenario: Apple Silicon macOS that already has Homebrew packages,
which is the realistic migration case

Deployment phase: Every `darwin-rebuild switch`

Files and lines: `nix/flake.nix:143-146`, generated Brewfile

Observed behavior: `homebrew.onActivation.cleanup = "uninstall"` renders as
`brew bundle --force-cleanup`, which uninstalls every Homebrew package not in
the Brewfile with no prompt. The generated Brewfile contains one tap and 21
casks. It declares no formulae and no Mac App Store apps at all.

Fresh-host consequence: On a truly stock Mac this does nothing, because there
is nothing to clean. On a Mac being migrated, the first switch uninstalls every
Homebrew formula on the machine, including formulae other software installed as
dependencies, plus every cask outside the 21. It keeps doing this on every
later switch, so anything the user installs with `brew` afterwards disappears
at the next activation without warning.

Reproduction or evidence: The activation text ends in `--force-cleanup`. The
generated Brewfile carries one `tap` line and 21 `cask` lines, and no `brew`
lines at all. `config.homebrew.brews` evaluates to `[]` and `config.homebrew.masApps`
to `{}`. The review host has 11 of the 21 cask applications already present in
`/Applications` and no Homebrew at all, so it is exactly the migration shape
this affects. Those 11 raise a second problem: Homebrew refuses to install a
cask over an application it did not place there, so several casks would fail to
adopt the existing copies even once `brew` exists.

Automated or manual: Automated, destructive, and silent

Current workaround: Uninstall or migrate other Homebrew packages before the
first switch, and never use `brew install` afterwards.

Recommended change: Use `cleanup = "zap"` only if that total ownership is
genuinely intended, and say so in `macos.md`. Otherwise drop to the default
`"none"`, or run one deliberate cleanup and then turn it off. Either way the
documentation should state that the flake owns the entire Homebrew prefix,
because right now `macos.md` describes Homebrew as an escape hatch for GUI
apps, which reads as the opposite.

Verification: On a snapshot with a handful of unrelated `brew` formulae and
casks installed, run the first switch and record exactly what is removed.
Repeat with the chosen setting and require the unrelated packages to survive.
Separately, install one cask application by hand and confirm whether the switch
adopts, replaces or fails on it.

Confidence: verified for the cleanup behavior, likely for the cask adoption
failure, which needs a host with Homebrew to reproduce

### A4M-005

Finding ID: A4M-005

Severity: medium

Platform and scenario: Every Apple Silicon macOS host

Deployment phase: First apply, and every `mup`

Files and lines: `dot_config/mise/mise.lock:1-176`,
`run_onchange_after_mise-install.sh.tmpl:40-46`,
`.chezmoitemplates/shell-interactive.sh:100`,
`README.md:66-79`, `docs/package-lists/mise.md:7-13`

Observed behavior: Every artifact entry in the committed lock carries a
`linux-x64` platform key and nothing else. The install hook branches on the OS
and runs a bare `mise install` on macOS, with no `--locked` and no
`MISE_CONFIG_DIR`. The macOS `mup` alias is
`mise lock --global --bump && mise install`, which writes an untracked
`~/.config/mise/mise.lock` that `.chezmoiignore` then leaves alone, and still
installs without `--locked`.

Fresh-host consequence: A fresh Mac has no lockfile of any kind, so all 28
tools resolve live at install time with no checksum verification and no
reviewable record of what landed. The repo argues elsewhere that supply-chain
safety is worth real friction, which is why `minimum_release_age` exists and
why six coding agents have named waivers. macOS gets none of the protection
that argument produces on Linux. The README does describe the macOS lock as
untracked, so the behavior is disclosed; what is missing is the verification,
not the documentation.

Reproduction or evidence: `MISE_CONFIG_DIR=<src>/dot_config/mise mise install
--dry-run --locked` on the review host failed with "No lockfile URL found ...
on platform macos-arm64 (--locked mode)" for `herdr`, `usage`, `codex`, `go`
and `node`, and skipped four npm tools as failed dependencies. Running
`mise lock --global --platform macos-arm64 --dry-run` against the same config
resolved all 28 tools successfully and left the committed lock's SHA-256
unchanged. Every version it resolved matches the committed Linux lock, so
adding macOS keys would change no versions. The live host shows what unlocked
resolution produces over time: `gh` is at 2.98.0 against the lock's 2.99.0.

Automated or manual: Automated, with unverified downloads

Current workaround: None. There is no supported way to install macOS tools from
a reviewed lock today.

Recommended change: Lock both platforms. Run
`mise lock --global --platform linux-x64 --platform macos-arm64`, commit the
result, and change the macOS branch of the install hook to use
`MISE_CONFIG_DIR` and `--locked` the way the Linux branch already does. Make
`mup` platform-aware in the same edit so a Mac refreshes the committed lock
instead of a private one.

Verification: After locking both platforms, require
`mise install --dry-run --locked` to pass on macOS and Linux from the same
committed file. On a fresh Mac with empty mise data and cache directories,
require the first apply to install only versions the lock names.

Confidence: verified

### A4M-006

Finding ID: A4M-006

Severity: medium

Platform and scenario: Every Apple Silicon macOS host, in every shell this repo
configures

Deployment phase: After the first nix-darwin activation, on any native build

Files and lines: `nix/flake.nix:80` (`gcc`),
`.chezmoitemplates/shell-path.sh:39-50`

Observed behavior: `pkgs.gcc` on aarch64-darwin installs 18 unprefixed
toolchain commands, among them `cc`, `c++`, `cpp`, `ld`, `as`, `ar`, `ranlib`,
`nm`, `objdump` and `strip`. `shell-path.sh` places
`/run/current-system/sw/bin` above the inherited PATH, and therefore above
`/usr/bin`. Every one of those names also exists in the Xcode Command Line
Tools, where they are clang and Apple's linker.

Fresh-host consequence: Anything that compiles native code from a shell this
repo sets up picks GCC 15 instead of Apple clang. That covers node-gyp builds
under the mise npm backend, Python C extensions built by `uv` for the pipx
backend, tree-sitter grammar compilation for Neovim, and luarocks. Building
against the macOS SDK with GCC is not a supported combination, and the failures
it produces are compile errors deep inside SDK headers rather than anything
that names the compiler choice. The package also costs 1.5 GiB of closure.

Reproduction or evidence: Listing `bin` for
`/nix/store/z861apmywyg8s66p669lk20s8sba1ns4-gcc-wrapper-15.3.0` from
`cache.nixos.org` returns the 18 names, and `cc` is a symlink rather than a
regular file. Intersecting the flake's 345 commands with `/usr/bin` produced 90
matches, including all of the toolchain names above. `nix path-info
--closure-size` reports 1.5 GiB. I did not run a native build, because that
means downloading the closure onto the review host.

Automated or manual: Automated

Current workaround: Call `/usr/bin/cc` explicitly, or set `CC=/usr/bin/clang`
before building.

Recommended change: Drop `gcc` unless something specific needs it. On macOS the
platform compiler is clang from the Command Line Tools, which the deployment
already requires. If GCC is needed for one particular build, add it to that
project's dev shell rather than to the system path. If it must stay system-wide,
list the Command Line Tools as a declared prerequisite and say which compiler
is meant to win.

Verification: After removing `gcc`, require `command -v cc` to return
`/usr/bin/cc` in a login shell, a non-login shell and an `ssh host command`
invocation. Then build one native npm module, one Python C extension through
`uv`, and one tree-sitter grammar, and require all three to succeed.

Confidence: verified for the shadowing, likely for the build failures

### A4M-007

Finding ID: A4M-007

Severity: medium

Platform and scenario: Apple Silicon macOS where mise exists but Nix has not
activated, or where mise came from somewhere other than the flake

Deployment phase: First apply

Files and lines: `run_onchange_after_mise-install.sh.tmpl:24-37`

Observed behavior: The hook requires `bun` and `uv` for its npm and pipx
backends. On Omarchy it installs whichever is missing with `omarchy pkg add`.
On every other host it prints "mise: missing required backend command" and
exits 1. A run script that exits non-zero fails the whole `chezmoi apply`.

Fresh-host consequence: On macOS the flake supplies `mise`, `bun` and `uv`
together, so the ordinary path is safe: before activation none of the three
exist and the hook exits 0 at its `command -v mise` guard. The failure needs
one of them without the others, which happens if the user installs mise from
Homebrew or the mise install script while following someone else's macOS
bootstrap. Then `chezmoi apply` aborts, and the message names the missing
command but not how to get it or that Nix is supposed to provide it.

Reproduction or evidence: The rendered macOS hook ends with the `exit 1` branch
followed by a bare `mise install`, and passes `bash -n`. The Omarchy branch of
the same template calls `omarchy pkg add` instead.

Automated or manual: Automated failure with an unhelpful message

Current workaround: Install `bun` and `uv` by hand, or remove the standalone
mise so the hook skips until Nix provides all three.

Recommended change: On macOS, say what supplies the missing command. Something
like "run `sudo darwin-rebuild switch --flake <src>/nix#macbook` first" turns a
dead end into an instruction. Exiting 0 with a warning is also defensible here,
since the hook already reruns when `lookPath "mise"` changes.

Verification: On a Mac with mise present and Nix absent, run `chezmoi apply`
and require either a successful skip or a message that names the fix. Then
activate and require the hook to rerun on the next apply.

Confidence: verified

### A4M-008

Finding ID: A4M-008

Severity: medium

Platform and scenario: Every Apple Silicon macOS host

Deployment phase: Bootstrap, and every apply afterwards

Files and lines: `.chezmoitemplates/shell-path.sh:39-50`,
`run_after_linux-package-drift.sh.tmpl:5-16`,
`.chezmoiignore.tmpl` (`linux-package-drift.sh`)

Observed behavior: `shell-path.sh` ranks `~/.local/bin`, `~/.cargo/bin` and
`$BUN_INSTALL/bin` above `/run/current-system/sw/bin`. The repo has a check for
exactly the drift that ordering invites, but it starts with
`[ "$(uname -s)" = Linux ] || exit 0` and is excluded from macOS by
`.chezmoiignore` as well. So macOS gets the hazard and not the detector.

Fresh-host consequence: chezmoi has to exist before Nix does, since it is what
clones and applies the repo that builds the first generation. The usual
bootstrap puts that binary in `~/.local/bin`, where it outranks the `chezmoi`
the flake later installs. From then on every apply runs the bootstrap copy, and
the flake's version is inert. The same applies to any `cargo install` or
`bun install -g` leftover. On Linux the drift script reports these; on macOS
nothing does. The script's stated reason for existing, that system packages are
Omarchy's job, does not transfer, because on macOS this repo does own the
system packages.

A related gap: mise never prunes. The review host still has
`npm:@openai/codex` 0.147.0 and `npm:opencode-ai` 1.18.18 installed from an
older declaration, alongside the `aqua` builds of the same two tools that the
current file declares, plus older builds of eight other tools. Nothing removes
them and nothing reports them.

Reproduction or evidence: The PATH list in `shell-path.sh` is explicit about
the order and the comment defends it for mise shims, but `~/.local/bin` sits
two lines above the Nix profile. `mise ls --json` on the review host lists 12
inactive installed versions with no requested version. `chezmoi ignored` on
macOS includes `linux-package-drift.sh`.

Automated or manual: Automated, undetected

Current workaround: Delete the bootstrap chezmoi by hand once Nix provides one,
and run `mise prune` occasionally.

Recommended change: Make the drift check cross-platform. Drop the `uname` guard
and the ignore entry, and on macOS extend it to compare the resolved path of
each Nix-declared command against `/run/current-system/sw/bin`. Adding `mise
prune --dry-run` output to the same report would cover the orphans.

Verification: With a stray `chezmoi` in `~/.local/bin`, run `chezmoi apply` on
macOS and require the hook to report it. Confirm the check stays quiet on a
clean host.

Confidence: verified

### A4M-009

Finding ID: A4M-009

Severity: low

Platform and scenario: Apple Silicon macOS where Nix owns mise, which is every
supported configuration

Deployment phase: Ongoing updates

Files and lines: `README.md:81-84`, `docs/package-lists/mise.md:37-39`

Observed behavior: Both documents say to update mise with `mise self-update`,
with no platform qualification. On macOS the flake declares `mise`, so the
binary lives in the read-only Nix store.

Fresh-host consequence: The documented update either fails outright or, if it
somehow wrote, would be reverted by the next `darwin-rebuild switch`, because
the store path is what the generation points at. Mise stays at whatever version
the flake's nixpkgs pin resolves until `nix flake update` moves it.

Reproduction or evidence: `mise` on the review host resolves to
`/run/current-system/sw/bin/mise`, which links to
`/nix/store/caclnwaxkz5c12y3yjzzjpfvndx9dvd9-mise-2026.8.3/bin/mise`, mode
`r-xr-xr-x`, on the `/nix` volume. Mise's own installation guide says
package-manager installations update through their package manager. This is the
same cause as the Linux report's A4-004, with a different owner.

Automated or manual: Incorrect manual instruction

Current workaround: `nix flake update --flake "$(chezmoi source-path)/nix"`
followed by a switch.

Recommended change: Make the mise update instruction platform-owned, the way
the `mup` paragraph already is. On macOS, updating mise means updating the
flake pin. The Linux reviewer proposed the same split for Omarchy, so one edit
covers both.

Verification: Follow the revised macOS instruction and require `mise --version`
to change after a flake update and switch. Confirm neither document tells a
macOS user to run `mise self-update`.

Confidence: verified

### A4M-010

Finding ID: A4M-010

Severity: low

Platform and scenario: Intel macOS

Deployment phase: First nix-darwin activation

Files and lines: `nix/flake.nix:24` (`nixpkgs.hostPlatform = "aarch64-darwin"`),
`nix/flake.nix:164` (`darwinConfigurations."macbook"`),
`docs/package-lists/macos.md:1-3,15-17`

Observed behavior: The flake defines one configuration, for `aarch64-darwin`
only. `macos.md` says "Apple Silicon macOS machines use nix-darwin" and that
`darwinConfigurations` defines only `macbook`, which describes the shape but
never states that Intel is unsupported. The README's ownership table says
"macOS" without qualification.

Fresh-host consequence: An Intel Mac cannot use this flake without adding a
configuration. Homebrew agrees independently: the `raycast` cask declares
`arch: arm64`. The lockfile boundary is the mirror image of the Linux report's
A4-003, which found `linux-x64` hardcoded with no stated support policy.

Reproduction or evidence: Static reading of the flake, plus the `depends_on`
field of the current `raycast` cask record. Not run on Intel hardware.

Automated or manual: Undocumented support boundary

Current workaround: Treat Apple Silicon as the only supported Mac.

Recommended change: State the supported platforms in one place. "Apple Silicon
macOS and Omarchy x86_64" in the README ownership table settles both this and
the Linux side in a sentence.

Verification: Follow the documented policy. If Intel support is ever wanted,
add an `x86_64-darwin` configuration, add `macos-x64` lock entries, and rerun
the cold-start protocol on Intel hardware.

Confidence: likely

### A4M-011

Finding ID: A4M-011

Severity: low

Platform and scenario: Apple Silicon macOS with Homebrew present

Deployment phase: Every `darwin-rebuild switch`

Files and lines: `nix/flake.nix:117` (`greedyCasks = true`),
`nix/flake.nix:143-146`, `docs/package-lists/macos.md:29-32`

Observed behavior: `macos.md` explains that casks stay outside the read-only
Nix store "so their own updaters still work". The flake then sets
`greedyCasks = true` alongside `upgrade = true`, which is the option that tells
Homebrew to upgrade casks that update themselves. Every cask line in the
generated Brewfile carries `greedy: true`.

Fresh-host consequence: The configuration does the opposite of what the
document says it is for. Twelve of the 21 casks report `auto_updates: true`,
and each switch re-downloads and reinstalls whichever of them Homebrew thinks
is behind, which can close a running application. It also makes every switch
slower and network-dependent in a way the drift hook's output does not predict.

Reproduction or evidence: `config.homebrew.casks` evaluates with
`greedy: true` on all 21 entries. The Homebrew API records `auto_updates: true`
for `adobe-acrobat-reader`, `bitwarden`, `chatgpt`, `claude`, `firefox`,
`ghostty`, `iterm2`, `obsidian`, `rancher`, `raycast`, `spotify`,
`visual-studio-code`, `zed` and `zotero`.

Automated or manual: Automated

Current workaround: None, short of editing the flake.

Recommended change: Pick one. Either drop `greedyCasks` and let the twelve
self-updating applications manage themselves, which is what `macos.md`
describes, or keep it and rewrite that paragraph to say the flake is the sole
authority on cask versions.

Verification: After the change, run two switches in a row with a self-updating
cask deliberately behind, and confirm the behavior matches whatever the
document now claims.

Confidence: verified

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check
sw_vers, uname -m, id -un
chezmoi data, chezmoi managed, chezmoi ignored, chezmoi source-path
chezmoi apply --dry-run --force --verbose --refresh-externals=never
  against an isolated destination and persistent state
nix flake metadata --no-write-lock-file
nix build --dry-run --no-link .#darwinConfigurations.macbook.system
  with and without NIXPKGS_ALLOW_UNFREE
nix eval of environment.systemPackages names, licences and outPaths
nix eval of homebrew.casks, brews, masApps, brewfile and onActivation
nix eval of system.activationScripts.homebrew.text
nix eval of the drift hook's own expression, with and without unfree allowed
nix store ls --store https://cache.nixos.org for the bin directory of all 73
  flake derivations
nix path-info --closure-size for gcc-wrapper
Homebrew API cask records for all 20 core-repository casks
mise ls, mise ls --json, mise which
MISE_CONFIG_DIR=<src>/dot_config/mise mise install --dry-run --locked
mise lock --global --platform macos-arm64 --dry-run, with a before-and-after
  checksum of the committed lock
set intersections of the 345 flake commands against the mise shims, the cask
  binaries, /usr/bin and /bin
bash -n on the rendered mise, darwin-rebuild, Doom and mise-trust hooks
TOML parse of the rendered Vim external declaration
resolution and permission check of the mise binary and its store path
```

The dry-run apply ran against an isolated destination rather than the live
home, so it changed nothing. I did not run `mise install`, `mise lock` without
`--dry-run`, `mise self-update`, `mise prune`, `nix flake update`, or any
`darwin-rebuild` command. Nothing was written to the live home directory or to
`/run/current-system`.

## Checks deferred to a disposable cold-start host

These need a machine I am willing to break.

- First `darwin-rebuild switch` on stock macOS after the unfree fix, with the
  full transcript, timing and download volume.
- The same switch with Homebrew absent, to confirm the silent skip end to end.
- Activation under a short account name other than `evelyn`.
- `brew bundle --force-cleanup` against a Mac carrying unrelated Homebrew
  formulae and casks, recording exactly what disappears.
- Cask installation over the 11 applications already present in
  `/Applications`, to see whether Homebrew adopts, replaces or refuses.
- Privileged installer prompts from `basictex`, `ltspice` and
  `adobe-acrobat-reader` during a non-interactive activation.
- A cold `mise install` with empty data and cache directories, and again with
  the network disabled.
- A native build of one npm module, one Python C extension and one tree-sitter
  grammar, with and without `gcc` in the flake.
- First, second and third apply convergence, including whether the Doom hook
  reruns after Emacs arrives from the switch.
- Whether `~/.local/bin/chezmoi` from the bootstrap keeps winning after the
  flake installs its own.
