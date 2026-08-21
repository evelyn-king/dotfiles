# Machine facts that cannot be read from chezmoi's own template data.
#
# Executed as a single `sh -c` by .chezmoi.toml.tmpl at `chezmoi init` time and
# frozen into ~/.config/chezmoi/chezmoi.toml. It is NOT re-run on apply: these
# answers are stable over a machine's life, and probing them costs a subprocess
# apiece. Re-run `chezmoi init` when one genuinely changes — you were granted
# sudo, you attached a display. See docs/layers.md.
#
# Contract: emit YAML on stdout and ALWAYS exit 0. chezmoi's `output` function
# aborts the whole template on a non-zero exit, so every probe below swallows
# its own failure. A fact that cannot be determined reports its safest value,
# which is always the one that unlocks the least.

# --- root -------------------------------------------------------------------
# Three ways to already be, or be able to become, root. `sudo -n` never
# prompts, so this is safe to run unattended; a machine that would ask for a
# password answers "no" here, which is the honest answer for a script that
# must not block.
root=false
if [ "$(id -u)" = "0" ]; then
  root=true
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  root=true
elif command -v doas >/dev/null 2>&1 && doas -n true >/dev/null 2>&1; then
  root=true
fi

# --- libc -------------------------------------------------------------------
# Decides which prebuilt binaries this machine can actually run, which is a
# different question from whether we may install packages. A no-root Ubuntu box
# still runs ordinary glibc release tarballs; only a musl host is restricted to
# static builds. Conflating the two over-restricts every Ubuntu deployment.
#
# `ldd --version` prints to stderr on glibc and exits 1 on musl, so both
# streams are merged and the exit status ignored.
libc=unknown
case "$(uname -s)" in
Darwin) libc=none ;;
*)
  if [ -n "$(ls /lib/ld-musl-* /lib/libc.musl-* 2>/dev/null)" ]; then
    libc=musl
  elif ldd --version 2>&1 | grep -qi musl; then
    libc=musl
  elif ldd --version 2>&1 | grep -qiE 'glibc|gnu libc'; then
    libc=glibc
  elif [ -n "$(ls /lib/*/libc.so.6 /lib64/libc.so.6 2>/dev/null)" ]; then
    libc=glibc
  fi
  ;;
esac

# --- desktop ----------------------------------------------------------------
# Whether a GUI session exists to configure. Deliberately not "is a GUI
# installed": a headless box with X libraries present still wants no theming.
desktop=false
case "$(uname -s)" in
Darwin) desktop=true ;;
*) [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && desktop=true ;;
esac

# --- writable prefix --------------------------------------------------------
# ~/.local/bin is the one install location the standalone layer relies on. A
# read-only or quota-full home is the failure mode that turns every later
# "install it yourself" instruction into a lie, so it is checked once, here.
prefix_writable=false
if mkdir -p "$HOME/.local/bin" 2>/dev/null && [ -w "$HOME/.local/bin" ]; then
  prefix_writable=true
fi

printf 'root: %s\nlibc: %s\ndesktop: %s\nprefixWritable: %s\n' \
  "$root" "$libc" "$desktop" "$prefix_writable"
