# PATH, built in the interactive rc rather than in the env file.
#
# macOS runs path_helper from /etc/zprofile and /etc/profile, which reorders
# anything an earlier stage prepended. Building PATH here — after that — is the
# only way to keep this order on macOS, and costs nothing on Linux.
#
# POSIX on purpose: the same text is included into both ~/.zshrc and ~/.bashrc,
# so no zsh arrays and no (N-/) glob qualifiers.
#
# The rule is first occurrence wins, matching what `typeset -U path` gave the
# zsh-only version: the list below is built first, then whatever PATH already
# held is appended minus anything already claimed. Listing a directory here is
# therefore what fixes its position, rather than inheriting wherever /etc put
# it — which matters for the nix profiles, since a system /etc/zshrc may well
# have added them somewhere else already.

# $GOPATH/bin leads and is deliberately not existence-checked: the first
# `go install` creates it, and by then the shell has long since started.
__path_new="$GOPATH/bin"

for __dir in \
  "$HOME/.local/bin" \
  "$HOME/.cargo/bin" \
  "$BUN_INSTALL/bin" \
  "$HOME/.rd/bin" \
  "$HOME/.config/emacs/bin" \
  "$HOME/.nix-profile/bin" \
  /run/current-system/sw/bin \
  /nix/var/nix/profiles/default/bin; do
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
