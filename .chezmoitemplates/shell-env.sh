# Environment shared by every shell. Included verbatim into ~/.zshenv and the
# top of ~/.bashrc, so it must stay POSIX — no arrays, no zsh glob qualifiers.
#
# PATH is deliberately NOT built here; see shell-path.sh for why.

export EDITOR=nvim
export VISUAL=$EDITOR

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Set here rather than behind a `go` check in the interactive rc: go comes from
# mise, which does not activate until well after PATH is built, so a guard
# there would always be false.
export GOPATH="$XDG_DATA_HOME/go"

# LANG only. Setting LC_ALL as well overrides every category unconditionally,
# which breaks on minimal Linux installs where this locale was never generated.
export LANG=en_US.UTF-8

# macOS hands each user a private /var/folders TMPDIR; this normalises it to
# match Linux. Harmless where /tmp is already the default.
export TMPDIR=/tmp

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
