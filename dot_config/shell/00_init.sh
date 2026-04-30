# 00_init.sh - common shell startups
# shellcheck shell=bash

export EDITOR="nvim"
export VISUAL="${EDITOR}"

export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

if [ "${SHELL_HAS_TTY:-0}" = "1" ]; then
  GPG_TTY="$(tty 2>/dev/null)"
  if [ -n "${GPG_TTY}" ]; then
    export GPG_TTY
  fi
else
  unset GPG_TTY
fi

export TMPDIR=/tmp

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export NLTK_DATA="${XDG_DATA_HOME}/nltk_data"

shell_path_prepend "${HOME}/.local/bin"
export MANPATH="${HOME}/.local/share/man:${MANPATH:-}"

export BUN_INSTALL="${HOME}/.bun"
shell_path_prepend "${BUN_INSTALL}/bin"

export DOCKER_DEFAULT_PLATFORM='linux/amd64'
