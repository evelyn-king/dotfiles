# Environment shared by the managed shell startup files. Included verbatim into
# ~/.zshenv and the top of ~/.bashrc, so it must stay POSIX: no arrays, no zsh
# glob qualifiers.
#
# Interactive shells do NOT build PATH here; they build it in the rc file after
# any macOS login path setup. See shell-path.sh for why, and the block at the
# bottom of this file for non-interactive shells that read a managed startup
# file.

export EDITOR=nvim
export VISUAL=$EDITOR

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Set here rather than behind a `go` check in the interactive rc: go comes from
# mise, which does not activate until well after PATH is built, so a guard
# there would always be false.
export GOPATH="$XDG_DATA_HOME/go"

# Preserve a valid inherited locale. Minimal Linux images often inherit an
# en_US.UTF-8 that was never generated, while macOS and Linux do not guarantee
# the same spelling. Pick the first available UTF-8 locale, then POSIX C as a
# last resort. LC_ALL is used only for the probe and is never exported.
if [ -z "${LANG:-}" ] || ! LC_ALL="$LANG" locale charmap >/dev/null 2>&1; then
  LANG=C
  for __locale in C.UTF-8 en_US.UTF-8 C; do
    if LC_ALL="$__locale" locale charmap >/dev/null 2>&1; then
      LANG=$__locale
      break
    fi
  done
  unset __locale
fi
export LANG

# Emacs on macOS starts its daemon in the per-user Darwin temp directory.
# emacsclient searches under TMPDIR, so a generic /tmp value makes the two
# processes disagree about the server socket. Preserve deliberate custom paths,
# but replace generic or missing values with the native per-user directory.
{{ if eq .chezmoi.os "darwin" }}
case "${TMPDIR:-}" in
"" | /tmp | /tmp/ | /private/tmp | /private/tmp/)
  __darwin_tmpdir=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)
  TMPDIR=${__darwin_tmpdir:-/tmp}
  unset __darwin_tmpdir
  ;;
esac
export TMPDIR
{{- else }}
export TMPDIR="${TMPDIR:-/tmp}"
{{- end }}

export NLTK_DATA="$XDG_DATA_HOME/nltk_data"
export BUN_INSTALL="$HOME/.bun"

export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.local/opt/micromamba}"

export JUPYTER_BIND_HOST=127.0.0.1
export JUPYTER_ENV_NAME=jupyter
export JUPYTER_PORT=8888
export JUPYTER_REMOTE_ENV_FILE="${JUPYTER_REMOTE_ENV_FILE:-$XDG_STATE_HOME/jupyter-remote/current.env}"
{{ if eq .chezmoi.os "darwin" }}
# Apple silicon runs amd64 images under emulation rather than failing to find a
# matching manifest. Not set on Linux, where the host arch is the right default
# and forcing amd64 on an arm box would emulate for no reason.
export DOCKER_DEFAULT_PLATFORM=linux/amd64
{{- end }}

# --- omarchy environment ----------------------------------------------------

# Omarchy's env-bootstrap exports OMARCHY_PATH and appends the mise shims and
# ~/.local/bin to PATH. Omarchy sources it from ~/.bashrc, which this repo
# replaces wholesale, so without this it is lost for zsh and for remote bash
# commands that sshd starts through .bashrc. Its own comment calls it "needed
# even for non-interactive shells".
#
# Sourcing it here rather than from ~/.bashrc also hands zsh the variable,
# which Omarchy's bash-only rc chain never did. Roots and their order match
# .chezmoitemplates/omarchy-detect.tmpl; first hit wins. Whatever it appends to
# PATH is reordered by shell-path.sh below, whose first-occurrence-wins rule
# puts the mise shims back in front.
for __dir in \
  "${OMARCHY_PATH:-}" \
  /usr/share/omarchy \
  "$HOME/.local/share/omarchy"; do
  if [ -r "$__dir/default/bash/env-bootstrap" ]; then
    . "$__dir/default/bash/env-bootstrap"
    break
  fi
done
unset __dir

# --- PATH for non-interactive shells ---------------------------------------

# Interactive shells skip this. They build PATH in ~/.zshrc or ~/.bashrc after
# any macOS login path setup has finished.
#
# zsh reads ~/.zshenv for every invocation, and sshd makes remote bash commands
# read ~/.bashrc. Without this block those commands inherit whatever bare PATH
# their parent handed over: no ~/.local/bin, no nix profiles, no ~/.cargo/bin.
# That is what made
# `ssh host jupyter-remote-lab` fail with "command not found" while the same
# command worked interactively. Cron, launchd, systemd units and directly
# executed Git hooks do not read these files and must set their own PATH.
#
# Nothing reorders PATH after this point in a non-interactive shell, so building
# it here is safe. The body is idempotent, first occurrence wins, so an
# interactive shell that somehow reached both copies still ends up with the same
# order.
case $- in
*i*) ;;
*)
{{ template "shell-path.sh" . }}
;;
esac
