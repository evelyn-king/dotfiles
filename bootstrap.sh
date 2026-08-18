#!/usr/bin/env bash
#
# Take a factory Mac to the point where chezmoi and nix-darwin can take over.
#
#   curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/main/bootstrap.sh | bash
#
# or, from an existing clone, ./bootstrap.sh
#
# This covers layers 0 and 1 only — Xcode CLT, Determinate Nix, the clone, and
# the first darwin-rebuild. Everything above that belongs to chezmoi, which
# this script hands off to at the end. See docs/bootstrap.md.
#
# Safe to re-run: every step checks before it acts.

set -euo pipefail

REPO_HTTPS="https://github.com/evelyn-king/dotfiles.git"
REPO_SSH="git@github.com:evelyn-king/dotfiles.git"
SOURCE_DIR="${HOME}/.local/share/chezmoi"
HOSTNAME_ATTR="lagrange"

say() { printf '\n\033[1m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mbootstrap:\033[0m %s\n' "$1" >&2; exit 1; }

# --- 0. sanity --------------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || die "macOS only."
[ "$(uname -m)" = "arm64" ] ||
  die "Apple silicon only — nix/flake.nix hardcodes nixpkgs.hostPlatform = \"aarch64-darwin\"."
[ "$(id -u)" -ne 0 ] || die "run as your own user, not root. One step calls sudo on its own."

# --- 1. Xcode Command Line Tools --------------------------------------------

if xcode-select -p >/dev/null 2>&1; then
  say "Xcode Command Line Tools already installed."
else
  say "Installing Xcode Command Line Tools (a GUI dialog will open)."
  xcode-select --install || true
  printf 'Waiting for the install to finish'
  until xcode-select -p >/dev/null 2>&1; do
    printf '.'
    sleep 10
  done
  printf '\n'
fi

# --- 2. Determinate Nix -----------------------------------------------------

# The flake sets nix.enable = false and leaves the daemon and /etc/nix/nix.conf
# to Determinate. Do not substitute another installer without changing that.
NIX_DAEMON_PROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

if [ -e /nix/var/nix/profiles/default/bin/nix ]; then
  say "Nix already installed."
else
  say "Installing Determinate Nix."
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
fi

# The installer edits shell rc files, which do not affect the running shell.
# shellcheck disable=SC1090
[ -e "$NIX_DAEMON_PROFILE" ] && . "$NIX_DAEMON_PROFILE"
command -v nix >/dev/null 2>&1 || die "nix is still not on PATH; open a new shell and re-run."

# --- 3. the repo ------------------------------------------------------------

# HTTPS on purpose: origin is an SSH remote, and a fresh machine has no key yet.
if [ -d "$SOURCE_DIR/.git" ]; then
  say "Repo already at $SOURCE_DIR."
else
  say "Cloning into $SOURCE_DIR."
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone "$REPO_HTTPS" "$SOURCE_DIR"
fi

# --- 4. first darwin-rebuild ------------------------------------------------

# `darwin-rebuild` does not exist yet — it arrives *in* the closure this builds.
# Hence `nix run` for the first switch and the plain command forever after.
if command -v darwin-rebuild >/dev/null 2>&1; then
  say "Activating the flake (darwin-rebuild switch)."
  sudo darwin-rebuild switch --flake "${SOURCE_DIR}/nix#${HOSTNAME_ATTR}"
else
  say "First activation via 'nix run' — darwin-rebuild is not installed yet."
  cat <<'EOF'

  If this aborts complaining that /etc/zshrc, /etc/bashrc or /etc/zshenv
  "would be clobbered": those are the Determinate installer's own files.
  Move each one aside and re-run:

    sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin

EOF
  sudo nix run nix-darwin/master#darwin-rebuild -- \
    switch --flake "${SOURCE_DIR}/nix#${HOSTNAME_ATTR}"
fi

# --- 5. hand off to chezmoi -------------------------------------------------

export PATH="/run/current-system/sw/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 || die "chezmoi missing after the switch; check the closure."

# chezmoi's default source dir is already $SOURCE_DIR, so init renders
# .chezmoi.toml.tmpl against the right tree. Applying pulls in the dotfiles and
# runs the hooks that install Doom, the rust toolchain and the mise tools.
say "Applying dotfiles (chezmoi init --apply)."
chezmoi init --apply

# --- 6. machine-local file, deliberately untracked --------------------------

EXTRAS="${XDG_CONFIG_HOME:-$HOME/.config}/shell/extras.sh"
if [ ! -f "$EXTRAS" ]; then
  say "Creating $EXTRAS for machine-local settings."
  mkdir -p "$(dirname "$EXTRAS")"
  printf '# Machine-local shell settings. Not tracked. Keep secrets here.\n' >"$EXTRAS"
  chmod 600 "$EXTRAS"
fi

# --- done -------------------------------------------------------------------

cat <<EOF

  Layers 0-3 are done. What is left is manual — see docs/bootstrap.md:

    - GUI applications (Ghostty, Zed, Obsidian, Rancher Desktop, ...)
    - Restore ~/.ssh/id_ed25519, then: ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    - Import the GPG signing key. dot_gitconfig sets commit.gpgsign = true,
      so every commit fails until that key is in the keyring.
    - git -C $SOURCE_DIR remote set-url origin $REPO_SSH
    - Fill in $EXTRAS

EOF
