# Agent 3 deployment review: Omarchy integration

> Subsequent ownership change: Pixi is now managed exclusively by mise on both
> platforms. The system-package inventories below describe the reviewed commit;
> see [the current mise tool list](package-lists/mise.md).

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Review date: 2026-09-02

Local review host: Omarchy 4.0.2-1, `omarchy` package 4.0.2-1, Ghostty
1.3.1-arch2, DP-3 at 5120x2160@120.042 scale 1.6666666

Scope: `.chezmoitemplates/omarchy-detect.tmpl`, the Omarchy branches in
`.chezmoiignore.tmpl` and Ghostty, `.chezmoidata/packages.yaml`,
`run_after_install-omarchy-packages.sh.tmpl`, `dot_config/hypr/**`, the Omarchy
shell integration, and `docs/package-lists/omarchy-linux.md`.

Nothing under `/usr/share/omarchy/` was modified. No package was installed, no
theme or monitor change was applied, and no refresh or reload was run. Every
check below is a read, a render, or a query against the live host.

## Workstream verdict

Omarchy is ready with documented manual steps. One high finding should land
before the next fresh host, because it costs a working keybinding and gives no
sign that it happened.

The detection template, the ignore gating, the package hook, and the Hypr and
Ghostty renders all behave as designed on Omarchy 4. The failures cluster at
one boundary, the places where Omarchy writes to a file chezmoi owns. There are
three of them, and in all three chezmoi wins on the next apply with no warning.
The rest is one display-specific value applied to every host, one 2.2 GiB
package no host needs by default, and five environment variables that stock
Omarchy exports and this repo's shell startup does not.

The shell integration is the best-reasoned part of the port. Every deviation
from Omarchy's bash chain except one carries a comment explaining the
trade-off, and the `default/bash/fns` loop handles both the Omarchy 3 and
Omarchy 4 directory layouts. The package hook is less careful about that same
version split (A3-006).

Twelve findings. Six can affect a fresh host, and six document behavior the
current docs do not cover.

## Detection truth table

Source: `.chezmoitemplates/omarchy-detect.tmpl`, four signals checked in order.
Verified rows were probed with `chezmoi execute-template` on this host. Derived
rows follow from the branch order and cannot be tested here.

| Scenario | `OMARCHY_PATH` | `osRelease.id` | `/usr/share/omarchy` | `~/.local/share/omarchy` | Result | Basis |
| --- | --- | --- | --- | --- | --- | --- |
| Packaged Omarchy 4 | unset | `omarchy` | present | absent | true | verified |
| Omarchy 4, interactive shell | `/usr/share/omarchy` | `omarchy` | present | absent | true | verified |
| Valid dev link | temp dir | `omarchy` | present | absent | true | verified |
| Stale `OMARCHY_PATH` | nonexistent | `omarchy` | present | absent | true, from signal 2 | verified |
| Empty `OMARCHY_PATH` | `""` | `omarchy` | present | absent | true, from signal 2 | verified |
| `OMARCHY_PATH` to any file | `/etc/passwd` | any | any | any | true, from signal 1 alone | verified |
| Legacy Omarchy 3 | unset | `arch` | absent | present | true | derived |
| Generic Linux | unset | `arch` | absent | absent | false | derived |
| Generic Linux, spurious env | any existing path | `arch` | absent | absent | true, see A3-005 | derived |
| Partial install, os-release only | unset | `omarchy` | absent | absent | true | derived |
| macOS | any | any | any | any | false, from the `os` guard | derived |

The `os` guard on line 28 means macOS never reaches any signal. Signals 2, 3
and 4 read no environment, so a systemd unit, a cron job or
`ssh host chezmoi apply` resolves the same as an interactive shell. That is the
property the template was written for and it holds. Signal 1 is the only
environment-dependent one, and it is the one that over-matches.

## Managed targets and the Ghostty branch

`.chezmoiignore.tmpl` and `dot_config/ghostty/config.tmpl` both call
`includeTemplate "omarchy-detect.tmpl"`, so they cannot disagree inside a
single render. Verified on this host that Ghostty took the Omarchy branch:
`ghostty +show-config` reports `font-size = 9` and `async-backend = epoll`.

| Target | Omarchy | Not Omarchy |
| --- | --- | --- |
| `.config/hypr/**` | managed, four files | ignored |
| `install-omarchy-packages.sh` | runs every apply | ignored |
| `.config/ghostty/config` | `font-size = 9`, `async-backend = epoll` | `font-size = 12`, no async-backend |

`linux-package-drift.sh` and `.config/superfile/**` are gated on Linux rather
than on Omarchy, so a generic Linux host still gets them. That reads as
intentional.

## Repo Hypr files against packaged defaults

`omarchy version` recorded before comparing: 4.0.2-1.

Nine files ship in `/usr/share/omarchy/config/hypr/`. The repo owns four.

| File | Managed | Divergence from the packaged default |
| --- | --- | --- |
| `hyprland.lua` | yes | identical plus one line, `hl.env("OMARCHY_SCREENSHOT_DIR", .../local-journal/screenshots)` |
| `bindings.lua` | yes | six bindings replacing the Hey, Grok and WhatsApp defaults with Google, Anthropic, Slack and Bitwarden |
| `looknfeel.lua` | yes | `rounding = 8` and `single_window_aspect_ratio = { 1.618, 1 }`, see A3-007 |
| `monitors.lua` | yes, templated | per-host profiles for gimli and maxwell, packaged default otherwise |
| `input.lua` | no | package-owned |
| `autostart.lua` | no | package-owned |
| `hyprsunset.conf` | no | package-owned |
| `xdph.conf` | no | package-owned |
| `.luarc.json` | no | package-owned |

The split is the right one and `docs/package-lists/omarchy-linux.md` already
explains why. The repo's `hyprland.lua` is a faithful copy of the 4.0.2
default, including the bootstrap `dofile` line that migration `1781063758.sh`
introduced, so it carries no stale entrypoint.

Syntax checks pass. `luac -p` accepts all three static Lua files and the
rendered `monitors.lua` for this hostname. `hyprctl configerrors` is empty.

## Omarchy migrations that touch managed files

Three of 97 migrations write to a file this repo owns. All three are stamped on
this host, so none will run here again. On a fresh host each runs once and the
next apply reverts it.

| Migration | Managed file | Effect | Status |
| --- | --- | --- | --- |
| `1780057136.sh` | `~/.config/ghostty/config` | appends the CSI-u Shift+Enter keybinds | A3-001 |
| `1781063758.sh` | `~/.config/hypr/hyprland.lua` | rewrites the entrypoint to the bootstrap `dofile` | no-op, the repo already carries it |
| `1781043107.sh` | ghostty config, `hyprland.lua` | rewrites `~/.config/omarchy/current` to `~/.local/state/omarchy/current` | no-op, the repo uses neither path |

`1781485962.sh` touches `input.lua` and `bindings.lua` but replaces them only
when the file hashes match a known stock value. The repo's `bindings.lua` is
not stock, so it is left alone. That migration is also what can create
`~/.local/state/omarchy/preinstalls-removed`, which is the trigger for A3-010.

Any future migration that edits one of the four managed Hypr files or the
Ghostty config will be undone the same way. That argues for a standing step in
the update runbook: after `omarchy update`, run `chezmoi diff` before
`chezmoi apply` and read what the migration wanted.

## Unmanaged modules on a fresh account

`hyprland.lua` calls `require("hypr.input")` and `require("hypr.autostart")`
directly rather than through `require_optional`. Neither file is managed, so
both must already exist or the Lua config fails to load.

`/etc/skel/.config/hypr/` holds all eight shipped files, so a normal
`useradd -m` account on an Omarchy host is provisioned before chezmoi runs.
Verified.

The gap is a home directory created without skel: a restored backup, a
container, `useradd -M`, or a home on a fresh volume. There
`require("hypr.input")` has nothing to load. This is narrow and I did not test
it. If it matters, the cheap fix is documenting
`omarchy refresh config hypr/input.lua` and `hypr/autostart.lua` as a
prerequisite, since both are refresh targets the repo does not own.

## Keybinding audit

All six repo bindings checked against
`/usr/share/omarchy/default/hypr/bindings/*.lua` at 4.0.2.

| Key | Repo binding | Packaged binding | Unbind present | Verdict |
| --- | --- | --- | --- | --- |
| `SUPER+SHIFT+ALT+A` | Claude webapp | Grok webapp | yes | correct |
| `SUPER+SHIFT+C` | Google Calendar | Hey Calendar | yes | correct |
| `SUPER+SHIFT+E` | Gmail | Hey | yes | correct |
| `SUPER+SHIFT+ALT+E` | Gmail compose | Hey compose | yes | correct |
| `SUPER+SHIFT+ALT+G` | Slack | WhatsApp | yes | correct |
| `SUPER+SHIFT+ALT+SLASH` | Bitwarden | none | not needed | correct, no collision |

`SUPER+SHIFT+ALT+SLASH` is genuinely free. The only SLASH bindings are
`SUPER+SLASH` for monitor scaling up, `SUPER+ALT+SLASH` for scaling down, and
`SUPER+SHIFT+SLASH` for 1Password. The comment in `bindings.lua` about sitting
alongside 1Password is accurate.

Launch commands and window classes:

`gtk-launch slack` with `focus = "^slack$"` routes through `o.launch_sole`,
which wraps the command with `uwsm-app`. `slack-desktop` is installed and its
class is `Slack`. Omarchy's launcher lowercases before matching, so the regex
should hit, but I did not confirm the focus behavior at runtime. One manual
check on the next cold start settles it.

`bitwarden-desktop` goes through `{ launch = ... }` and the `bitwarden` package
provides `/usr/bin/bitwarden-desktop`. Verified installed.

The four webapps use `omarchy-launch-webapp`, the packaged path. None sets
`focus = true`, matching the packaged behavior for those keys. The one
exception is WhatsApp, which had `focus = true`. Its Slack replacement uses
`launch` plus `focus`, which produces the same launch-or-focus behavior.

The five unbinds that depend on `preinstalled_bindings_enabled()` are A3-010.

## Monitors, scaling and the unknown-host fallback

`hyprctl monitors all` reports `DP-3 5120x2160@120.042 scale 1.6666666`, which
matches the gimli branch's `mode = "5120x2160@120.00"`. Hyprland accepts the
rounded refresh rate.

The unknown-host branch is a verbatim copy of the packaged `monitors.lua`, so
an unrecognized hostname gets exactly the Omarchy default: `output = ""`,
`mode = "preferred"`, `scale = "auto"`, `GDK_SCALE=2`. That is the right
fallback and the branch renders and compiles clean.

Two problems, both below: the fractional `GDK_SCALE` on gimli (A3-002) and the
runtime scaling command writing to a managed file (A3-003).

The maxwell branch names `DP-2` at `3440x1440@100.00` plus `eDP-1` and can only
be validated on that hardware. Per the plan, named monitor profiles are tested
only on matching hardware.

## Conflicts between chezmoi and Omarchy commands

| Omarchy action | Managed file it writes | Result |
| --- | --- | --- |
| `omarchy hyprland monitor scaling`, SUPER+SLASH | `hypr/monitors.lua` | reverted next apply, A3-003 |
| `omarchy refresh hyprland` | all four Hypr files | reverted next apply, `.bak.<epoch>` left behind, A3-009 |
| `omarchy refresh config hypr/<file>` | one Hypr file | same |
| `omarchy update` migrations | ghostty config, `hyprland.lua` | reverted next apply, A3-001 |
| `omarchy theme set` | none | writes `~/.local/state/omarchy/current/theme`, which no managed file reads |
| `omarchy pkg add` | none | additive, no conflict |

`omarchy theme set` deserves a note to the owner as expected behavior rather
than a bug. It changes desktop chrome and leaves Ghostty alone, because the
repo's config drops the packaged
`config-file = ?"~/.local/state/omarchy/current/theme/ghostty.conf"` line.
`docs/package-lists/omarchy-linux.md` documents this.

## Package classification

All 46 declared pacman packages resolve and all 46 are installed on this host.
43 come from core and extra, 3 from Omarchy's own repository, which
`docs/package-lists/omarchy-linux.md` rightly says belongs under `pacman`. Both
AUR entries are installed and neither is in any pacman repo, so the
`pacman`/`aur` split is right.

| Source | Count | Packages |
| --- | --- | --- |
| `core` | 1 | pinentry |
| `extra` | 42 | aspell, aspell-en, ast-grep, atuin, bat, bitwarden, bitwarden-cli, btop, bun, chezmoi, cmake, direnv, duf, dust, emacs-wayland, eza, fd, firefox, fzf, ghostty, git-delta, graphviz, hyperfine, keychain, lazygit, lua-language-server, neovim, ollama-cuda, pixi, ripgrep, sccache, shellcheck, starship, superfile, tailscale, tealdeer, uv, vim, zed, zellij, zoxide, zsh |
| `omarchy` | 3 | dropbox, dropbox-cli, visual-studio-code-bin |
| AUR through `yay` | 2 | google-cloud-cli, slack-desktop |

Requirements the repo does not automate:

| Package | Requirement |
| --- | --- |
| ollama-cuda | an NVIDIA GPU for any benefit. Pulls `cuda`, 2.20 GiB down and 4.71 GiB installed, on every host. `ollama.service` is disabled and models are pulled by hand. See A3-004 |
| tailscale | `systemctl enable --now tailscaled` plus `tailscale up` browser auth. Enabled on this host by hand, not by the repo |
| dropbox, dropbox-cli | daemon start and account sign-in |
| bitwarden, bitwarden-cli | vault sign-in and unlock |
| google-cloud-cli | `gcloud auth login`, needs a browser |
| slack-desktop | workspace sign-in. yay builds it from a downloaded `.deb`, so a network or upstream URL failure fails the apply |
| visual-studio-code-bin | proprietary Microsoft build, license acceptance on first launch |
| zsh | installed but never made the login shell. `~/.bashrc` hands off instead, which is deliberate and documented |
| emacs-wayland | needed by `install-doom-emacs.sh`, which sorts before the package hook |

Hook semantics read from source. `omarchy-pkg-add` calls `omarchy-pkg-missing`
first and invokes `sudo pacman -S --noconfirm --needed` only when something is
actually missing, so a no-op apply does not prompt for sudo. That confirms the
claim in `docs/package-lists/omarchy-linux.md`. `omarchy-pkg-aur-add` does the
same before calling `yay -S --noconfirm --needed`.

One note for agent 1. chezmoi orders `run_after_` scripts by target name, which
on this repo gives `darwin-rebuild.sh`, `install-doom-emacs.sh`,
`install-omarchy-packages.sh`, `linux-package-drift.sh`, `mise-install.sh`,
`trust-local-projects-mise.sh`. On a fresh Omarchy host with no emacs, Doom's
hook runs before the package hook installs `emacs-wayland`. It handles that.
The hook prints "Emacs is not installed; skipping" and exits 0, and
`lookPath "emacs"` is baked into the rendered script body so a second apply
retries. The first apply is a two-pass operation by design rather than a
failure. The cold-start runbook should say so rather than leave the user to
discover it.

## Shell startup against the Omarchy bash chain

Omarchy's `default/bash/rc` sources six files. What this repo's replacement does
with each:

| Omarchy file | Contents | Repo handling |
| --- | --- | --- |
| `env-bootstrap` | `OMARCHY_PATH`, mise shims and `~/.local/bin` on PATH | re-sourced from `shell-env.sh`, so zsh and non-interactive shells get it too. Better than the original |
| `envs` | EDITOR, SUDO_EDITOR, BROWSER, BAT_THEME, MANROFFOPT, MANPAGER, locale fallback | not re-sourced. EDITOR and BAT_THEME replaced on purpose. BROWSER, MANPAGER and MANROFFOPT lost without comment, see A3-008 |
| `shell` | histappend, HISTCONTROL, HISTSIZE, bash_completion, `set +h` | equivalents in `dot_bashrc.tmpl`. Verified `HISTCONTROL=ignoreboth`, `HISTSIZE=100000`, `set +h` |
| `aliases` | ls, lt, ff, zd, git and tool aliases | deliberately not sourced. `h`, `a`, `ic`, `ix` and `icx` restated, each with a comment naming the collision |
| `functions`, then `fns/*` | compression, drives, herdr, rsyncing, ssh-*, tmux, worktrees | sourced for bash only. zsh gets the hand-ported `tdl` in `shell-omarchy-zsh.zsh` |
| `init` | mise, starship, zoxide, try, fzf, completions | the repo does its own. Only `completions` is taken, with a comment on why the rest is not |
| `inputrc` | readline settings | `dot_inputrc` is a superset: identical body plus vi mode, `keyseq-timeout 25`, `show-mode-in-prompt` |

Everything here except the `envs` exports is a deliberate choice with its
reasoning written down. A3-008 is the one gap.

## Ghostty

`ghostty +validate-config` exits 0 at Ghostty 1.3.1-arch2. `ghostty
+show-config` resolves the font chain to `CaskaydiaCove Nerd Font Mono`,
`FiraCode Nerd Font Mono`, `JetBrainsMono Nerd Font`, `JetBrains Mono`, with
`font-size = 9`, `theme = light:Gruvbox Light,dark:Gruvbox Dark` and
`async-backend = epoll`.

The leading `font-family = ""` clears Ghostty's built-in list as intended, and
the chain resolves to `JetBrainsMono Nerd Font`, the only family in it
installed here. It ships as `ttf-jetbrains-mono-nerd-basic`, a hard dependency
of the `omarchy` package. The template's comment about fontconfig answering an
unknown family with a near match rather than failing checks out:
`fc-match 'CaskaydiaCove Nerd Font Mono'` returns JetBrainsMono. Ghostty does
its own per-entry discovery instead of going through that fallback, which is
why naming JetBrainsMono explicitly matters. Bold, italic and bold-italic all
inherit the same chain.

Intended differences from the packaged default, all sound:

`theme = "light:Gruvbox Light,dark:Gruvbox Dark"` replaces the packaged
`config-file` line, so `omarchy theme set` no longer reaches the terminal.
Documented. `background-opacity = 1.00` and `working-directory = home` are
additions. `font-size = 9` and `async-backend = epoll` match the packaged
Omarchy values and are gated to the Omarchy branch.

The unintended difference is the two missing CSI-u keybinds, A3-001.

## Findings

### A3-001

Finding ID: A3-001

Severity: high

Platform and scenario: Omarchy, every host, after any `omarchy update`

Deployment phase: Post-first-apply, ongoing

Files and lines: `dot_config/ghostty/config.tmpl:48-53`

Observed behavior: Stock Omarchy 4.0.2 ships two Ghostty keybinds this repo's
config does not carry, `keybind = shift+enter=csi:13;2u` and
`keybind = alt+shift+enter=csi:13;4u`. They live in
`/usr/share/omarchy/config/ghostty/config`, and migration `1780057136.sh`
appends them to `$HOME/.config/ghostty/config` on hosts that predate them.
That file is chezmoi-managed, so the next apply reverts the migration's edit.
Migrations run once per user: `omarchy-migrate` stamps each one under
`~/.local/state/omarchy/migrations`, and this host holds 97 stamps for 97
migrations. The edit has already been reverted here. `ghostty +show-config`
reports no `shift+enter` or `alt+shift+enter` binding at all.

Fresh-host consequence: A fresh Omarchy 4 host installs with both keybinds in
the shipped config. The first `chezmoi apply` replaces that config and drops
them. Shift+Enter and Alt+Shift+Enter revert to the legacy encoding, so TUIs
cannot tell them from plain Enter. Codex, Claude and tmux matching M-S-Enter
all lose the distinction. The migration that would restore them is either
already stamped or gets stamped and immediately reverted, so there is no
recovery short of editing the repo. Nothing errors and nothing warns.

Reproduction or evidence:
`diff <(sed -n '/keybind/p' /usr/share/omarchy/config/ghostty/config) <(ghostty
+show-config | sed -n '/^keybind/p')`. Migration body:
`rg -n 'ensure_ghostty_binding' /usr/share/omarchy/migrations/1780057136.sh`.
Stamp count: `ls ~/.local/state/omarchy/migrations | wc -l` and
`ls /usr/share/omarchy/migrations | wc -l` both return 97.

Automated or manual: Automated loss, manual recovery

Current workaround: None in the repo

Recommended change: Add both keybinds to `dot_config/ghostty/config.tmpl`
unconditionally, next to the existing `shift+insert` and `control+insert`
lines. They are terminal-encoding fixes rather than Omarchy-specific settings,
so the macOS branch wants them too.

Verification: `ghostty +show-config | grep -E 'shift\+enter|alt\+shift\+enter'`

Confidence: verified

### A3-002

Finding ID: A3-002

Severity: medium

Platform and scenario: Omarchy, hostname `gimli` only

Deployment phase: Post-apply, every session

Files and lines: `dot_config/hypr/monitors.lua.tmpl:8-11`

Observed behavior: The gimli branch sets `local omarchy_gdk_scale = 1.6667` and
passes it through `hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))`. GTK reads
`GDK_SCALE` as an integer. Omarchy's own `omarchy-hyprland-monitor-scaling`
says so in a comment, "GTK only honors integer GDK_SCALE values, so persist the
nearest whole factor even when the monitor scale itself is fractional", and
writes `int(scale + 0.5)` instead. `GDK_SCALE=1.6667` is live in the
environment of GTK clients on this host.

Fresh-host consequence: GTK applications render at scale factor 1 and the
compositor upscales them to 1.6667, rather than rendering at 2 and being
scaled down. On a 5120x2160 panel that is visible softness in every GTK app.
Nothing errors, so the cold-start smoke test passes.

Reproduction or evidence:
`tr '\0' '\n' < /proc/$(pgrep -f quickshell | head -1)/environ | grep
GDK_SCALE` returns `GDK_SCALE=1.6667`. Omarchy's reasoning:
`sed -n '/GTK only honors integer/,+2p' $(which
omarchy-hyprland-monitor-scaling)`.

Automated or manual: Automated

Current workaround: Run `omarchy hyprland monitor scaling 1.6`, which rewrites
the line to 2, until the next apply reverts it. See A3-003.

Recommended change: Set `local omarchy_gdk_scale = 2` in the gimli branch,
matching what Omarchy's own scaling command persists for a 1.6667 monitor
scale. Leave `omarchy_monitor_scale` at 1.6667.

Verification: After apply and `hyprctl reload`, relaunch a GTK app and confirm
`GDK_SCALE=2` in its `/proc/<pid>/environ`.

Confidence: verified for the variable value. Likely for the rendering
consequence, since GTK's integer parse rests on Omarchy's comment rather than
on something I observed.

### A3-003

Finding ID: A3-003

Severity: medium

Platform and scenario: Omarchy, any host, SUPER+SLASH and SUPER+ALT+SLASH

Deployment phase: Post-apply, interactive

Files and lines: `dot_config/hypr/monitors.lua.tmpl:4-6`

Observed behavior: `omarchy-hyprland-monitor-scaling` persists a scale change
by running `sed -i -E` against `$HOME/.config/hypr/monitors.lua`, rewriting the
`^local omarchy_monitor_scale = ` and `^local omarchy_gdk_scale = ` lines.
`monitors.lua` is rendered from a hostname-gated chezmoi template. The repo
keeps those two `local` names on purpose so the sed matches, and the file
comment says the rewrite makes "a scale change survive a reboot". It does. It
does not survive the next `chezmoi apply`, which restores the template value
without a word. A comment that is half right is worse here than no comment,
because it tells the reader the change is safe.

Fresh-host consequence: This is the only file in the repo that Omarchy and
chezmoi both write. A scale picked from the keyboard or the shell settings
panel is discarded at the next apply, with no signal that it happened. The
audit log on this host records two such changes made from quickshell.

Reproduction or evidence: `cat ~/.local/state/omarchy/monitor-scaling.log`
shows the two changes. The write itself:
`sed -n '/Persist to monitors.lua/,+12p' $(which
omarchy-hyprland-monitor-scaling)`.

Automated or manual: Automated revert

Current workaround: Change the scale in the template rather than at runtime.

Recommended change: An owner decision, not a code fix. Either accept it and
correct the file comment, replacing "so a scale change survives a reboot" with
a note that the template is the source of truth and a runtime change has to be
copied back, or stop managing `monitors.lua` on hosts without a named profile
and let Omarchy own the generic fallback it already handles.

Verification: `omarchy hyprland monitor scaling 1.25 && chezmoi status
.config/hypr/monitors.lua`

Confidence: verified

### A3-004

Finding ID: A3-004

Severity: medium

Platform and scenario: Omarchy, every host including non-NVIDIA

Deployment phase: First apply

Files and lines: `.chezmoidata/packages.yaml`, the `ollama-cuda` pacman entry

Observed behavior: `ollama-cuda` depends on `cuda`, which is 2.20 GiB to
download and 4.71 GiB installed, plus ollama-cuda's own 724 MiB and 988 MiB.
Every Omarchy host gets it, maxwell's Framework 13 included. Nothing in the
repo enables `ollama.service`, and it is disabled on this host.

Fresh-host consequence: The first apply spends roughly 3 GB of download and
5.7 GB of disk on a CUDA runtime a non-NVIDIA host cannot use, for a daemon
that never starts and models that are never pulled. On a metered or slow link
this dominates first-apply time.

Reproduction or evidence:
`pacman -Si ollama-cuda | grep -E 'Depends On|Download Size|Installed Size'`
and `pacman -Si cuda | grep -E 'Download Size|Installed Size'`.
`systemctl is-enabled ollama` returns `disabled`.

Automated or manual: Automated install, manual service enable and model pull

Current workaround: None

Recommended change: Two separate calls. First, gate the accelerated variant on
the host. Keep `ollama` in the shared pacman list and add `ollama-cuda` only
for hosts with an NVIDIA GPU, through a hostname key in `packages.yaml` or a
template condition in the hook. extra also carries `ollama-rocm` and
`ollama-vulkan`. Second, document `systemctl enable --now ollama` and the model
pull in the manual-state inventory, or drop ollama if it is not actually used.

Verification: `chezmoi execute-template --file
run_after_install-omarchy-packages.sh.tmpl | grep ollama`

Confidence: verified

### A3-005

Finding ID: A3-005

Severity: medium

Platform and scenario: Non-Omarchy Linux with `OMARCHY_PATH` set

Deployment phase: Template render, every apply

Files and lines: `.chezmoitemplates/omarchy-detect.tmpl:29-31`

Observed behavior: The first branch is
`{{- if and $envPath (ne (stat $envPath) nil) -}}`. `stat` succeeds on anything
that exists, so a regular file or an empty directory passes. The template's own
header says `OMARCHY_PATH` is "never relied on alone", but this branch does
exactly that. It short-circuits before the os-release and filesystem checks.

Fresh-host consequence: A generic Linux host that inherits or sets
`OMARCHY_PATH` to any existing path is detected as Omarchy. chezmoi then
manages `~/.config/hypr/**`, four Lua files a non-Omarchy Hyprland cannot load
because they call `hl` and `o` and require `default.hypr.omarchy`, and runs the
package hook, which invokes a missing `omarchy` binary under `set -e` and fails
the apply. Stale and empty values behave correctly and fall through.

Reproduction or evidence: Isolating the branch with a probe template on this
host gives `branch1_fires=yes` for `OMARCHY_PATH=/etc/passwd` and for an empty
directory, and `branch1_fires=no` for a nonexistent path, an empty string, and
an unset variable.

Automated or manual: Automated

Current workaround: None

Recommended change: Require the path to look like an Omarchy root rather than
merely exist. `stat (joinPath $envPath "default/hypr/bootstrap.lua")` would do
it, or `joinPath $envPath "bin"` at minimum. That also matches how
`shell-env.sh` probes the same roots, checking for `default/bash/env-bootstrap`
rather than the bare directory.

Verification: Rerun the probe. Only a real root should fire branch 1.

Confidence: verified for the branch behavior. Likely for the downstream apply
failure, which I did not test on a non-Omarchy host.

### A3-006

Finding ID: A3-006

Severity: medium

Platform and scenario: Omarchy 3 host, or any host where `omarchy` is absent

Deployment phase: First apply and every apply

Files and lines: `run_after_install-omarchy-packages.sh.tmpl:10-33`

Observed behavior: The hook runs `omarchy pkg add` and `omarchy pkg aur add`
under `set -euo pipefail` with no `command -v omarchy` guard. The unified
`omarchy <group> <action>` dispatcher is an Omarchy 4 interface. Omarchy 3
shipped individual `omarchy-*` scripts under `~/.local/share/omarchy/bin`,
which Omarchy 4's own migration `1788102906.sh` still refers to by that path.
`omarchy-detect.tmpl` keeps `~/.local/share/omarchy` as a signal "so an
unmigrated host still matches", so the repo claims Omarchy 3 support this hook
cannot deliver.

Fresh-host consequence: On an Omarchy 3 host, detection returns true, chezmoi
writes the Hypr files, and the hook aborts the apply on its first command.
Because it is `run_after_` rather than `run_once_`, every later apply fails the
same way. Every hook sorting after it alphabetically never runs:
`linux-package-drift`, `mise-install`, `trust-local-projects-mise`.

Reproduction or evidence:
`rg -n 'omarchy pkg' run_after_install-omarchy-packages.sh.tmpl` for the calls.
`rg -n 'local/share/omarchy/bin'
/usr/share/omarchy/migrations/1788102906.sh` for the Omarchy 3 layout.

Automated or manual: Automated failure

Current workaround: None

Recommended change: Guard the hook with
`command -v omarchy >/dev/null 2>&1 || { echo "omarchy CLI not found; skipping
package restore." >&2; exit 0; }`. That matches how `install-doom-emacs.sh`
already handles missing git and emacs, and keeps a partial or legacy host from
failing an otherwise good apply. Otherwise drop Omarchy 3 from the detection
template if no such host exists any more, and say so in
`docs/package-lists/omarchy-linux.md`.

Verification: `PATH=/usr/bin:/bin chezmoi execute-template --file
run_after_install-omarchy-packages.sh.tmpl | bash -n`, plus a dry run on a host
without the dispatcher.

Confidence: likely. The Omarchy 3 layout is inferred from Omarchy 4's own
migrations rather than tested on a v3 host.

### A3-007

Finding ID: A3-007

Severity: medium

Platform and scenario: Omarchy, every host

Deployment phase: Post-apply

Files and lines: `dot_config/hypr/looknfeel.lua:14-21`

Observed behavior: `single_window_aspect_ratio = { 1.618, 1 }` applies
unconditionally. `looknfeel.lua` is a static source file rather than a
template, so the hostname gating `monitors.lua.tmpl` uses is not available to
it. The comment in the file names the reason as "this 5K2K display".

Fresh-host consequence: On maxwell's Framework 13 internal panel, and on any
16:9 external, a golden-ratio single-window layout leaves unused margin on a
display that was never too wide. This is a host-specific choice applied
everywhere rather than a failure. The packaged default leaves the setting
commented out and suggests `{ 1, 1 }`.

Reproduction or evidence: `diff
/usr/share/omarchy/config/hypr/looknfeel.lua dot_config/hypr/looknfeel.lua`

Automated or manual: Automated

Current workaround: None

Recommended change: An owner policy call. Either accept it as a global
preference and delete the "this 5K2K display" justification from the comment,
or rename the file to `looknfeel.lua.tmpl` and gate the block the same way
`monitors.lua.tmpl` is gated. The rename is the smaller change and keeps
per-host desktop settings in one place.

Verification: `hyprctl getoption layout:single_window_aspect_ratio` on each
host.

Confidence: verified

### A3-008

Finding ID: A3-008

Severity: medium

Platform and scenario: Omarchy, every host, every shell

Deployment phase: Post-apply, first-run authentication

Files and lines: `.chezmoitemplates/shell-env.sh:9-10`, `dot_bashrc.tmpl:60-68`

Observed behavior: `~/.bashrc` replaces Omarchy's, which sourced
`$OMARCHY_PATH/default/bash/rc`. The repo re-sources three pieces of that chain
and documents each: `env-bootstrap` in `shell-env.sh`, `default/bash/fns` in
`shell-interactive.sh` for bash only, and `default/bash/completions` in
`dot_bashrc.tmpl`. It also restates the `h`, `a`, `ic`, `ix` and `icx` aliases
and the `set +h` hashing behavior. `default/bash/envs` is not re-sourced and
its exports are not restated, leaving five variables empty that stock Omarchy
sets: `BROWSER`, `MANPAGER`, `MANROFFOPT`, `BAT_THEME` and `SUDO_EDITOR`.
`EDITOR` is replaced on purpose with nvim, and `BAT_THEME` is dropped on
purpose because the repo names Gruvbox directly, as
`docs/package-lists/omarchy-linux.md` says. The other three are not mentioned
anywhere.

Fresh-host consequence: `BROWSER` is the one that costs something at
deployment time. Omarchy's own comment says it exists so terminal programs
"open URLs detached from the terminal process tree", and it is shell-scoped on
purpose so `xdg-settings` still works. Without it, `gh auth login`,
`gcloud auth login`, `tailscale up` and Bitwarden fall back to `xdg-open`,
which stays attached to the terminal. Those are the first commands the
cold-start runbook has the user run. `MANPAGER` and `MANROFFOPT` cost colored
man pages. `SUDO_EDITOR` is harmless, because sudo falls back to `VISUAL`,
which `shell-env.sh` sets.

Reproduction or evidence:
`zsh -lic 'printf "%s|%s|%s|%s\n" "$BROWSER" "$MANPAGER" "$BAT_THEME"
"$SUDO_EDITOR"'` prints `|||`, all empty. `bash -lic 'echo "[$BROWSER]"'`
prints `[]`. The originals are in
`sed -n '1,12p' /usr/share/omarchy/default/bash/envs`.

Automated or manual: Undocumented manual work

Current workaround: Set them per host in `~/.config/shell/extras.sh`.

Recommended change: Export `BROWSER=omarchy-launch-browser` from the Omarchy
block in `shell-env.sh`, guarded on the command being present, next to the
existing `env-bootstrap` loop. Add `MANPAGER` and `MANROFFOPT` if colored man
pages are wanted. Add a line to `docs/package-lists/omarchy-linux.md` listing
what the `~/.bashrc` replacement drops on purpose. The doc currently lists only
what it keeps.

Verification: `zsh -lic 'echo $BROWSER'`, then confirm `gh browse` opens
detached.

Confidence: verified

### A3-009

Finding ID: A3-009

Severity: low

Platform and scenario: Omarchy, after `omarchy refresh hyprland`

Deployment phase: Post-apply, recovery

Files and lines: `dot_config/hypr/**`

Observed behavior: `omarchy-refresh-hyprland` calls `omarchy-refresh-config` on
all seven shipped Hypr files, four of which chezmoi manages. Each refresh
copies the current file to `<name>.bak.<epoch>` and replaces it with the
packaged default.

Fresh-host consequence: The desktop reverts to stock until the next apply
restores the repo copies. The `.bak.<epoch>` files stay in `~/.config/hypr/`
indefinitely, because chezmoi does not manage them and nothing removes them.
`omarchy refresh config hypr/<file>` on a single managed file does the same.

Reproduction or evidence: `cat $(which omarchy-refresh-hyprland)` for the file
list, `sed -n '/backup_config_file/p' $(which omarchy-refresh-config)` for the
backup behavior.

Automated or manual: Manual trigger, automated revert

Current workaround: `chezmoi apply` restores the files. Delete the `.bak` files
by hand.

Recommended change: Documentation only. Add to
`docs/package-lists/omarchy-linux.md` that on this repo `chezmoi apply` is the
recovery path rather than `omarchy refresh hyprland`, and that the refresh
leaves `.bak.<epoch>` files behind. The three unmanaged files, `input.lua`,
`autostart.lua` and `hyprsunset.conf`, remain legitimate refresh targets.

Verification: `chezmoi status .config/hypr` after a refresh.

Confidence: verified

### A3-010

Finding ID: A3-010

Severity: low

Platform and scenario: Omarchy with preinstalled bindings disabled

Deployment phase: Post-apply, Hyprland config load

Files and lines: `dot_config/hypr/bindings.lua:8-24`

Observed behavior: Five of the six `hl.unbind` calls target bindings that exist
only inside `if o.preinstalled_bindings_enabled()` in
`/usr/share/omarchy/default/hypr/bindings/applications.lua`:
`SUPER+SHIFT+ALT+A`, `SUPER+SHIFT+C`, `SUPER+SHIFT+E`, `SUPER+SHIFT+ALT+E` and
`SUPER+SHIFT+ALT+G`. That predicate is false when
`~/.local/state/omarchy/preinstalls-removed` exists, which Omarchy's own
migration `1781485962.sh` creates for hosts that had stripped the preinstalled
bindings, or when `omarchy_preinstalled_bindings = false` is set in
`hyprland.lua`, which the repo's own `hyprland.lua` documents as an option.

Fresh-host consequence: Unknown. If `hl.unbind` on an unregistered key is a
no-op, nothing happens and the repo's `o.bind` calls take effect normally. If
it raises, the Lua config fails to load. This host has preinstalled bindings
enabled and `hyprctl configerrors` is clean, so I could not tell which.

Reproduction or evidence:
`rg -n 'preinstalled_bindings_enabled' /usr/share/omarchy/default/hypr/` and
`rg -n 'preinstalls-removed' /usr/share/omarchy/migrations/1781485962.sh`.

Automated or manual: Automated

Current workaround: None needed on a default host.

Recommended change: Test it in a snapshot before assuming it is safe.
`touch ~/.local/state/omarchy/preinstalls-removed`, then `hyprctl reload` and
`hyprctl configerrors`. If it raises, the fix is a helper that unbinds only
when the key is bound. If it is a no-op, add a one-line comment saying so.

Verification: `hyprctl configerrors` with the state file present.

Confidence: hypothesis

### A3-011

Finding ID: A3-011

Severity: low

Platform and scenario: Omarchy, stock install

Deployment phase: Bootstrap, before the first apply

Files and lines: `README.md`, `.chezmoidata/packages.yaml`, the `chezmoi`
pacman entry

Observed behavior: Stock Omarchy 4.0.2 does not supply chezmoi. It is not a
dependency of the `omarchy` package and appears nowhere in
`/usr/share/omarchy/install/`. On this host it is installed explicitly with
nothing requiring it.

Fresh-host consequence: The Omarchy cold-start runbook has to begin with
`sudo pacman -S chezmoi` before `chezmoi init`. Listing chezmoi in
`packages.yaml` keeps it installed afterwards but cannot bootstrap it. This
confirms the plan's lead that the documentation starts at `chezmoi apply`
rather than at a stock host, and it contradicts agent 1's Omarchy timeline,
which expects a stock image to supply chezmoi.

Reproduction or evidence: `pacman -Qi omarchy | grep 'Depends On'` does not
list chezmoi. `rg -n '\bchezmoi\b' /usr/share/omarchy/install/` returns no
matches. `pacman -Qi chezmoi | grep -E 'Install Reason|Required By'` shows
`Explicitly installed` and `Required By : None`.

Automated or manual: Undocumented manual work

Current workaround: Install it by hand.

Recommended change: One line at the top of the Omarchy runbook.

Verification: On a fresh snapshot, run `command -v chezmoi` before any repo
step.

Confidence: verified

### A3-012

Finding ID: A3-012

Severity: low

Platform and scenario: Omarchy, every apply

Deployment phase: Every apply, removal phase

Files and lines: `.chezmoiremove`, the
`.config/omarchy/extensions/menu.sh` and `.config/omarchy/hooks/theme-set`
entries

Observed behavior: Both are permanent deletions of paths inside Omarchy's own
user config tree, in a file whose header calls its entries one-time migration
cleanup that should be pruned. Neither collides with a current Omarchy 4 path.
`omarchy hook install theme-set <script>` writes into
`~/.config/omarchy/hooks/theme-set.d/`, and menu overrides moved to
`extensions/omarchy-menu.jsonc`.

Fresh-host consequence: None today. The risk is forward-looking. These are
deletions of paths a future Omarchy version or a hand-written hook could
legitimately occupy, and they run on every apply rather than once.

Reproduction or evidence:
`sed -n '/menu.sh/p;/hooks\/theme-set/p' .chezmoiremove` and
`ls /usr/share/omarchy/config/omarchy/`.

Automated or manual: Automated

Current workaround: None needed.

Recommended change: Defer to agent 7's persistent-removal policy and to agent
1's A1-001, which covers the same file at blocker severity. From the Omarchy
side, both entries are safe to prune once every host has applied at least once.
Neither is needed for correctness on Omarchy 4.

Verification: Apply on a host with a hand-written theme-set hook.

Confidence: verified

## Manual-state inventory

| Item | Classification |
| --- | --- |
| Install chezmoi before the first apply | undocumented manual, A3-011 |
| Second apply so Doom picks up `emacs-wayland` | undocumented manual |
| `systemctl enable --now tailscaled`, `tailscale up` | undocumented manual |
| `systemctl enable --now ollama`, model pull | undocumented manual, A3-004 |
| Dropbox daemon start and sign-in | undocumented manual |
| Bitwarden vault sign-in | undocumented manual |
| `gcloud auth login` | undocumented manual |
| Slack workspace sign-in | undocumented manual |
| VS Code license acceptance | undocumented manual |
| Reboot into Hyprland after the first apply | undocumented manual |
| Per-host monitor profile for a new hostname | documented, the unknown-host fallback is the packaged default |
| Omarchy package restore | automated, `run_after_install-omarchy-packages.sh.tmpl` |
| Hypr and Ghostty config | automated |
| Omarchy shell bootstrap, fns, completions | automated |
| `~/.config/hypr/input.lua` and `autostart.lua` | intentionally unmanaged, provisioned by `/etc/skel` |
| Login shell change to zsh | intentionally unmanaged, `~/.bashrc` hands off |
| Theme switching for terminal, editors and btop | intentionally unmanaged, Gruvbox is named directly |

## Suggested patch order

Ranked by deployment risk, for the coordinator's queue. No remediation has been
started and the shared worktree is untouched.

1. A3-001, add the two Ghostty CSI-u keybinds. A permanent regression on every
   fresh host, fixed in one line.
2. A3-006, guard the package hook on `command -v omarchy`. Turns a total apply
   failure into a skip, and matches how the Doom hook already behaves.
3. A3-005, require the `OMARCHY_PATH` target to look like an Omarchy root.
4. A3-002, set `omarchy_gdk_scale = 2` on gimli.
5. A3-008, export `BROWSER` from the Omarchy block in `shell-env.sh`.
6. A3-004, gate `ollama-cuda` on the GPU, or drop ollama. Needs an owner
   decision.
7. A3-007, hostname-gate `single_window_aspect_ratio`, or drop the
   display-specific justification. Needs an owner decision.
8. A3-003 and A3-009, document the chezmoi and Omarchy write conflicts.
9. A3-010, test the preinstalls-removed case in a snapshot before deciding.
10. A3-011, one line at the top of the Omarchy runbook.
11. A3-012, fold into agent 7's persistent-removal decision.

Policy questions for the owner, which the plan says must be resolved before
remediation:

Is Omarchy 3 still supported? The detection template says yes, the package hook
assumes Omarchy 4's CLI (A3-006).

Should `monitors.lua` stay managed on hosts without a named profile, given that
Omarchy writes to it at runtime (A3-003)?

Is ollama wanted at all, and on which hosts (A3-004)?

Is the golden-ratio single-window layout a global preference or a gimli setting
(A3-007)?

## Checks run

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
git diff --check

omarchy version
pacman -Qo /usr/share/omarchy/version
pacman -Qi omarchy
pacman -Sl, then per-package repo and install lookup for all 48 declarations
pacman -Si ollama-cuda, cuda
systemctl is-enabled ollama tailscaled

chezmoi execute-template --file dot_config/hypr/monitors.lua.tmpl
chezmoi execute-template --file dot_config/ghostty/config.tmpl
chezmoi execute-template --file run_after_install-omarchy-packages.sh.tmpl
chezmoi apply --dry-run --force --verbose --refresh-externals=never
  into an isolated destination and persistent state
chezmoi status
probe templates isolating each omarchy-detect.tmpl branch under six
  OMARCHY_PATH values

luac -p on bindings.lua, hyprland.lua, looknfeel.lua and rendered monitors.lua
hyprctl configerrors
hyprctl monitors all
ghostty +validate-config, +show-config, +list-fonts
fc-match on all four font-family entries
rendered package hook through bash -n

diff against /usr/share/omarchy/config/hypr/* and config/ghostty/config
read /usr/share/omarchy/default/hypr/* and default/bash/*
rg over /usr/share/omarchy/migrations for managed-file writes
read omarchy-pkg-add, omarchy-pkg-aur-add, omarchy-pkg-missing,
  omarchy-refresh-hyprland, omarchy-refresh-config,
  omarchy-hyprland-monitor-scaling, omarchy-migrate
zsh -lic and bash -lic environment probes
GDK_SCALE read from a live GTK client's /proc/<pid>/environ
```

The review did not install packages, change a theme or monitor scale, run any
refresh or reload, or modify anything under `/usr/share/omarchy/`. Testing the
Omarchy 3 path, the non-Omarchy false positive, the preinstalls-removed case,
and the maxwell monitor profile all need a disposable host or matching
hardware.
