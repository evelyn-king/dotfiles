#!/bin/sh
#
# Take an unprivileged machine to the point where chezmoi can take over.
#
#   curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/main/bootstrap-standalone.sh | sh
#
# This is the counterpart to bootstrap.sh, which assumes a Mac, sudo and Nix.
# This one assumes none of those. It is the entry point for the `standalone`
# layer: a shared Ubuntu box, a locked-down build agent, a container you did
# not build. See docs/layers.md.
#
# POSIX sh on purpose, not bash. The floor this targets includes images that
# ship only /bin/sh, and a bashism here would fail on exactly the machines the
# script exists for.
#
# It installs ONE binary: chezmoi. Everything above that is the standalone
# layer's own job, because once chezmoi is on the box the repo can describe its
# own provisioning instead of this script duplicating it. In particular mise —
# the thing that actually makes an unprivileged machine usable — is fetched by
# run_onchange_after_fetch-portable-tools.sh, not here.
#
# Set BOOTSTRAP_DRY_RUN=1 to print the resolved plan and exit without touching
# the network or the filesystem. BOOTSTRAP_REPO_URL and BOOTSTRAP_REPO_REF let
# a test or review build apply a specific repository snapshot; normal installs
# use the production URL and its default branch.

set -eu

REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/evelyn-king/dotfiles.git}"
REPO_REF="${BOOTSTRAP_REPO_REF:-}"
BINDIR="${BINDIR:-$HOME/.local/bin}"
DRY="${BOOTSTRAP_DRY_RUN:-0}"

say() { printf '\n\033[1m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mbootstrap-standalone:\033[0m %s\n' "$1" >&2; exit 1; }

# --- 0. the tools this script itself needs ----------------------------------
#
# Deliberately checked up front and named individually. A machine missing curl
# AND wget cannot be bootstrapped from the network at all, and saying so now is
# kinder than failing three steps in.

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1"; }
  fetch_head_url() { curl -fsSLI -o /dev/null -w '%{url_effective}' "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
  # wget prints the redirect chain to stderr; the last Location wins.
  fetch_head_url() {
    wget -qS --spider "$1" 2>&1 |
      sed -n 's/^ *Location: *\([^ ]*\).*/\1/p' |
      tr -d '\r' |
      tail -1
  }
else
  die "neither curl nor wget is available; cannot fetch anything."
fi

# busybox, coreutils and macOS each spell this differently.
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  die "no sha256sum or shasum; refusing to install an unverified binary."
fi

# --- 1. what machine is this ------------------------------------------------
#
# This duplicates .chezmoitemplates/facts.sh, unavoidably: that file is inside
# the repo, and the repo is not on the machine yet. The two must agree on what
# counts as musl. If you change one, change both.

case "$(uname -m)" in
x86_64 | amd64) ARCH=amd64 ;;
aarch64 | arm64) ARCH=arm64 ;;
*) die "unsupported architecture: $(uname -m)." ;;
esac

OS=$(uname -s)
LIBC=glibc
case "$OS" in
Darwin)
  LIBC=none
  ;;
Linux)
  if [ -n "$(ls /lib/ld-musl-* /lib/libc.musl-* 2>/dev/null)" ]; then
    LIBC=musl
  elif ldd --version 2>&1 | grep -qi musl; then
    LIBC=musl
  fi
  ;;
*) die "unsupported OS: $OS." ;;
esac

# --- 2. pick the chezmoi asset ----------------------------------------------
#
# Upstream's matrix is not symmetric, and the gap matters here. As of chezmoi
# 2.72.0 the published Linux artefacts are:
#
#   amd64  bare binary, both glibc and musl variants   chezmoi-linux-amd64[-musl]
#   arm64  tarball only, no musl variant               chezmoi_<v>_linux_arm64.tar.gz
#
# So an arm64 musl host — Alpine on a Graviton or a Pi — has no purpose-built
# binary. The generic arm64 build is used instead and may or may not run;
# that is called out rather than papered over, because the failure otherwise
# looks like a corrupt download.

CHEZMOI_VERSION=""
NEEDS_TAR=0
case "$OS-$ARCH-$LIBC" in
Linux-amd64-musl) ASSET="chezmoi-linux-amd64-musl" ;;
Linux-amd64-glibc) ASSET="chezmoi-linux-amd64" ;;
Linux-arm64-*)
  NEEDS_TAR=1
  [ "$LIBC" = musl ] &&
    printf '\033[1;33mwarning:\033[0m no musl build of chezmoi for arm64; trying the generic one.\n' >&2
  ;;
Darwin-*)
  die "this is a Mac — use bootstrap.sh, which sets up Nix and nix-darwin too."
  ;;
*) die "no chezmoi asset for $OS-$ARCH-$LIBC." ;;
esac

# The arm64 path needs the version in the filename, so resolve the tag from the
# redirect that /releases/latest performs. One HEAD request, no API token, no
# rate limit worth worrying about.
if [ "$NEEDS_TAR" -eq 1 ]; then
  if [ "$DRY" = 1 ]; then
    CHEZMOI_VERSION="<resolved-at-runtime>"
  else
    tag=$(fetch_head_url "https://github.com/twpayne/chezmoi/releases/latest")
    CHEZMOI_VERSION=${tag##*/v}
    [ -n "$CHEZMOI_VERSION" ] || die "could not resolve the latest chezmoi version."
  fi
  ASSET="chezmoi_${CHEZMOI_VERSION}_linux_arm64.tar.gz"
fi

BASE="https://github.com/twpayne/chezmoi/releases/latest/download"

if [ "$DRY" = 1 ]; then
  printf 'os=%s arch=%s libc=%s\nasset=%s\ntarball=%s\nbindir=%s\n' \
    "$OS" "$ARCH" "$LIBC" "$ASSET" "$NEEDS_TAR" "$BINDIR"
  exit 0
fi

# --- 3. install chezmoi -----------------------------------------------------

if command -v chezmoi >/dev/null 2>&1; then
  say "chezmoi already installed at $(command -v chezmoi)."
else
  mkdir -p "$BINDIR" || die "cannot create $BINDIR."
  [ -w "$BINDIR" ] || die "$BINDIR is not writable; the standalone layer needs it."

  tmp=$(mktemp -d) || die "cannot create a temporary directory."
  trap 'rm -rf "$tmp"' EXIT INT TERM

  say "Downloading $ASSET."
  fetch "$BASE/$ASSET" >"$tmp/$ASSET" || die "download failed: $BASE/$ASSET"

  # Verified before anything is made executable. The checksums file is named
  # with the version, which for the bare-binary paths we have not resolved —
  # so resolve it here if we did not already.
  if [ -z "$CHEZMOI_VERSION" ]; then
    tag=$(fetch_head_url "https://github.com/twpayne/chezmoi/releases/latest")
    CHEZMOI_VERSION=${tag##*/v}
  fi
  say "Verifying checksum."
  sums=$(fetch "$BASE/chezmoi_${CHEZMOI_VERSION}_checksums.txt") ||
    die "could not fetch the checksums file."
  # Exact string comparison, not a regex: asset names contain dots, and a
  # loose pattern could match a neighbouring line's hash. mise prefixes its
  # entries with ./ and chezmoi does not, so both spellings are accepted.
  want=$(printf '%s\n' "$sums" | while read -r h f; do
    case "$f" in
    "$ASSET" | "./$ASSET")
      printf '%s' "$h"
      break
      ;;
    esac
  done)
  [ -n "$want" ] || die "$ASSET is not listed in the checksums file."
  got=$(sha256 "$tmp/$ASSET")
  [ "$want" = "$got" ] || die "checksum mismatch for $ASSET (want $want, got $got)."

  if [ "$NEEDS_TAR" -eq 1 ]; then
    command -v tar >/dev/null 2>&1 || die "tar is needed to unpack $ASSET."
    (cd "$tmp" && tar xzf "$ASSET" chezmoi)
    mv "$tmp/chezmoi" "$BINDIR/chezmoi"
  else
    mv "$tmp/$ASSET" "$BINDIR/chezmoi"
  fi
  chmod 755 "$BINDIR/chezmoi"
  say "Installed $BINDIR/chezmoi."
fi

PATH="$BINDIR:$PATH"
export PATH

# --- 4. hand off to chezmoi -------------------------------------------------
#
# --use-builtin-git matters more than it looks. A locked-down box frequently
# has no git at all, and git is not something you can drop in as a static
# binary the way the Go and Rust tools below can. chezmoi's built-in client
# clones over HTTPS without it, which is what makes a git-less bootstrap work.

say "Applying dotfiles (chezmoi init --apply)."
if [ -n "$REPO_REF" ]; then
  chezmoi init --apply --use-builtin-git=true --branch "$REPO_REF" "$REPO_URL"
else
  chezmoi init --apply --use-builtin-git=true "$REPO_URL"
fi

cat <<EOF

  Done. Active layers:

    layers

  If $BINDIR is not on your PATH yet, start a new shell — the applied
  ~/.bashrc puts it there. Until then, use the full path.

  The standalone layer has fetched mise into $BINDIR. What it installs is
  ~/.config/mise/conf.d/20-standalone.toml, deliberately smaller than the
  full set: run 'mise install' after a new shell to pick up the rest.

EOF
