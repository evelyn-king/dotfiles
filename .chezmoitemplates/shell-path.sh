# PATH, built in the interactive rc rather than in the env file.
#
# macOS runs path_helper from /etc/zprofile and /etc/profile, which reorders
# anything an earlier stage prepended. Building PATH here, after that has run,
# is the only way to keep this order on macOS, and costs nothing on Linux.
#
# Two callers include this body, and only one is the interactive rc.
# shell-env.sh also runs it for non-interactive shells, which never reach
# path_helper and would otherwise get no PATH at all. Keep it idempotent. The
# first-occurrence-wins rule below is what makes running it twice harmless.
#
# POSIX on purpose: the same text is included into ~/.zshrc, ~/.bashrc and
# (via shell-env.sh) ~/.zshenv and ~/.profile, so no zsh arrays and no (N-/)
# glob qualifiers.
#
# The rule is first occurrence wins, matching what `typeset -U path` gave the
# zsh-only version: the list below is built first, then whatever PATH already
# held is appended minus anything already claimed. Listing a directory here is
# therefore what fixes its position, rather than inheriting wherever /etc put
# it. That matters for the nix profiles, since a system /etc/zshrc may well have
# added them somewhere else already.
#
# Homebrew is listed for the same reason, and ranks below the nix profiles: it
# is the escape hatch for casks, not the primary source of CLI tools. Do not
# call `brew shellenv` from a later stage instead. It prepends unconditionally,
# so it would land ahead of the tool paths `mise activate` adds later in the
# interactive rc and quietly shadow every mise-managed runtime.

# $GOPATH/bin leads and is deliberately not existence-checked: the first
# `go install` creates it, and by then the shell has long since started.
__path_new="$GOPATH/bin"

# The mise shims lead, ahead of ~/.local/bin. Interactive shells do not
# depend on that order, since `mise activate` prepends the real install
# dirs later. Non-interactive shells have only the shims, and those are
# exactly the shells this order protects: a hand-installed binary dropped
# into ~/.local/bin must not outrank the version mise pins for SSH
# commands, cron jobs and hooks. ~/.local/bin keeps its own scripts.
for __dir in \
  "$XDG_DATA_HOME/mise/shims" \
  "$HOME/.local/bin" \
  "$HOME/.cargo/bin" \
  "$BUN_INSTALL/bin" \
  "$HOME/.rd/bin" \
  "$HOME/.config/emacs/bin" \
  "$HOME/.nix-profile/bin" \
  /run/current-system/sw/bin \
  /nix/var/nix/profiles/default/bin \
  /opt/homebrew/bin \
  /opt/homebrew/sbin; do
  [ -d "$__dir" ] || continue
  case ":$__path_new:" in
  *":$__dir:"*) ;;
  *) __path_new="$__path_new:$__dir" ;;
  esac
done

# Walk the inherited PATH by hand rather than splitting on IFS: zsh does not
# word-split unquoted parameters, so an `IFS=: for d in $PATH` loop that looks
# correct in bash silently iterates once in zsh.
__path_rest=$PATH
while [ -n "$__path_rest" ]; do
  __dir=${__path_rest%%:*}
  case "$__path_rest" in
  *:*) __path_rest=${__path_rest#*:} ;;
  *) __path_rest= ;;
  esac
  [ -n "$__dir" ] || continue
  case ":$__path_new:" in
  *":$__dir:"*) ;;
  *) __path_new="$__path_new:$__dir" ;;
  esac
done

# Lower priority than anything inherited: pixi shims should not shadow a real
# tool that is already on PATH.
for __dir in \
  "$HOME/.pixi/bin"{{ if eq .chezmoi.os "darwin" }} \
  "/Applications/Obsidian.app/Contents/MacOS"{{ end }}; do
  [ -d "$__dir" ] || continue
  case ":$__path_new:" in
  *":$__dir:"*) ;;
  *) __path_new="$__path_new:$__dir" ;;
  esac
done

PATH=$__path_new
export PATH
unset __dir __path_new __path_rest

# path_helper manages MANPATH too, so it belongs here for the same reason.
export MANPATH="$HOME/.local/share/man:${MANPATH:-}"
