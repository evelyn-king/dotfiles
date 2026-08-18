#!/usr/bin/env bash
#
# Take a fresh macOS, Ubuntu or Arch machine to the point chezmoi can take
# over. Arch here includes its derivatives, Omarchy among them.
#
#   curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/machinetype/portable/bootstrap.sh | bash
#
# or, from an existing clone, ./bootstrap.sh
#
# This installs the two things chezmoi cannot install for itself — git and
# chezmoi — and then hands off. It deliberately does not install the tools the
# dotfiles configure: every config here detects what it finds at runtime, so a
# missing tool costs you that tool and nothing else. See docs/bootstrap.md.
#
# Safe to re-run: every step checks before it acts.

set -euo pipefail

REPO_HTTPS="https://github.com/evelyn-king/dotfiles.git"
REPO_SSH="git@github.com:evelyn-king/dotfiles.git"
BRANCH="${DOTFILES_BRANCH:-machinetype/portable}"

say() { printf '\n\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mbootstrap:\033[0m %s\n' "$1" >&2; }
die() {
  printf '\033[1;31mbootstrap:\033[0m %s\n' "$1" >&2
  exit 1
}

[ "$(id -u)" -ne 0 ] || die "run as your own user, not root. Package steps call sudo on their own."

# --- 1. identify the platform -----------------------------------------------

# PLATFORM is one of: macos, ubuntu, arch. Anything else stops here rather than
# guessing at a package manager. IS_WSL is tracked separately: WSL reports
# ID=ubuntu, so it is the same platform for packaging purposes but differs in
# how git credentials are stored.
IS_WSL=0

case "$(uname -s)" in
Darwin)
  PLATFORM=macos
  ;;
Linux)
  [ -r /etc/os-release ] || die "no /etc/os-release; cannot identify this Linux."
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
  # Omarchy is Arch underneath and reports ID_LIKE=arch, so the generic arm
  # below would catch it. Name it anyway: the ID_LIKE line is the distro's to
  # change, and dropping to "unsupported Linux" on a machine pacman runs on
  # perfectly well would be a poor way to find that out.
  omarchy:* | arch:* | *:*arch*) PLATFORM=arch ;;
  ubuntu:* | debian:* | *:*debian*) PLATFORM=ubuntu ;;
  *) die "unsupported Linux '${ID:-unknown}'. Supported: ubuntu/debian, arch/omarchy." ;;
  esac
  # WSL1 kernels end in "-Microsoft", WSL2 contain "-microsoft-standard".
  # WSL_DISTRO_NAME is the belt-and-braces check for stripped-down kernels.
  osrelease=$(tr '[:upper:]' '[:lower:]' </proc/sys/kernel/osrelease 2>/dev/null || true)
  case "$osrelease" in
  *microsoft*) IS_WSL=1 ;;
  *) [ -n "${WSL_DISTRO_NAME:-}" ] && IS_WSL=1 ;;
  esac
  ;;
*)
  die "unsupported OS '$(uname -s)'. Supported: macOS, Ubuntu, Arch."
  ;;
esac

if [ "$IS_WSL" -eq 1 ]; then
  say "Platform: $PLATFORM (under WSL)"
else
  say "Platform: $PLATFORM"
fi

# --- 2. git -----------------------------------------------------------------

# chezmoi needs git to clone, and cannot bootstrap it.
install_git() {
  case "$PLATFORM" in
  macos)
    # git arrives with the Command Line Tools. The installer is a GUI dialog.
    if xcode-select -p >/dev/null 2>&1; then
      die "Command Line Tools are installed but git is still missing; investigate by hand."
    fi
    say "Installing the Xcode Command Line Tools (a GUI dialog will open)."
    xcode-select --install || true
    printf 'Waiting for the install to finish'
    until xcode-select -p >/dev/null 2>&1; do
      printf '.'
      sleep 10
    done
    printf '\n'
    ;;
  ubuntu)
    say "Installing git (sudo apt-get)."
    sudo apt-get update -qq
    sudo apt-get install -y git ca-certificates curl
    ;;
  arch)
    say "Installing git (sudo pacman)."
    sudo pacman -Sy --needed --noconfirm git ca-certificates curl
    ;;
  esac
}

if command -v git >/dev/null 2>&1; then
  say "git already installed."
else
  install_git
  command -v git >/dev/null 2>&1 || die "git is still missing after the install step."
fi

# --- 3. chezmoi -------------------------------------------------------------

# The upstream standalone installer works identically on all three platforms
# and needs no package manager, which keeps this step from having to care what
# each distro happens to call the package.
CHEZMOI_BIN="${HOME}/.local/bin"

if command -v chezmoi >/dev/null 2>&1; then
  say "chezmoi already installed ($(command -v chezmoi))."
else
  say "Installing chezmoi into $CHEZMOI_BIN."
  mkdir -p "$CHEZMOI_BIN"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$CHEZMOI_BIN"
  export PATH="$CHEZMOI_BIN:$PATH"
fi

command -v chezmoi >/dev/null 2>&1 || die "chezmoi is not on PATH; open a new shell and re-run."

# --- 4. hand off to chezmoi -------------------------------------------------

# HTTPS on purpose: origin is an SSH remote, and a fresh machine has no key yet.
# init --apply clones, renders .chezmoi.toml.tmpl, writes the dotfiles and runs
# the run_ hooks (mise install, rust toolchain, Doom) — each of which no-ops if
# the tool it drives is absent.
say "Applying dotfiles from $BRANCH."
chezmoi init --apply --branch "$BRANCH" "$REPO_HTTPS"

SOURCE_DIR="$(chezmoi source-path)"

# --- 5. machine-local file, deliberately untracked --------------------------

EXTRAS="${XDG_CONFIG_HOME:-$HOME/.config}/shell/extras.sh"
if [ ! -f "$EXTRAS" ]; then
  say "Creating $EXTRAS for machine-local settings."
  mkdir -p "$(dirname "$EXTRAS")"
  printf '# Machine-local shell settings. Not tracked. Keep secrets here.\n' >"$EXTRAS"
  chmod 600 "$EXTRAS"
fi

# --- 6. report what is deliberately left undone -----------------------------

command -v mise >/dev/null 2>&1 ||
  warn "mise is not installed, so no runtimes or global CLI tools were set up."

# ~/.config/git/config points at Git Credential Manager on the Windows side.
# If Git for Windows is not installed, the rendered path is a default rather
# than a resolved one and every authenticated fetch will fail on a missing
# helper.
if [ "$IS_WSL" -eq 1 ]; then
  gcm_found=0
  for gcm in \
    "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" \
    "/mnt/c/Program Files (x86)/Git/mingw64/bin/git-credential-manager.exe" \
    "/mnt/c/Program Files/Git/mingw64/libexec/git-core/git-credential-manager-core.exe"; do
    [ -x "$gcm" ] && gcm_found=1 && break
  done
  [ "$gcm_found" -eq 1 ] ||
    warn "Git Credential Manager not found under /mnt/c. Install Git for Windows on the host, then re-run 'chezmoi apply' so ~/.config/git/config picks up the real path."

  # Neovim picks this up automatically once it is on PATH; without it there is
  # no clipboard provider under WSL at all. See docs/bootstrap.md.
  command -v win32yank.exe >/dev/null 2>&1 ||
    warn "win32yank.exe not on PATH. Neovim yanks will not reach the Windows clipboard."
fi

cat <<EOF

  Dotfiles are applied. What is left is yours to do — see docs/bootstrap.md:

    - Install the tools you want. Nothing here installs them, and every config
      degrades quietly when one is missing. mise covers the runtimes and CLI
      tools once it exists: install it, then run 'chezmoi apply' again.
    - Install a Nerd Font. ghostty pins "CaskaydiaCove Nerd Font" by name, and
      starship and 'eza --icons' need the glyphs.
    - Restore ~/.ssh/id_ed25519 and add it to your agent.
    - Import the GPG signing key. ~/.config/git/config sets
      commit.gpgsign = true, so every commit fails until that key is in the
      keyring.
    - git -C $SOURCE_DIR remote set-url origin $REPO_SSH
    - Fill in $EXTRAS

EOF
