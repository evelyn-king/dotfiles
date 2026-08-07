# 10_bash_init.sh - init bash-preexec and bash-completion
# shellcheck shell=bash

if [ -n "${BASH_VERSION:-}" ] && [ "${SHELL_IS_INTERACTIVE:-0}" = "1" ]; then
  bash_preexec="${HOME}/.bash-preexec.sh"
  if [ -f "${bash_preexec}" ]; then
    # shellcheck source=/dev/null
    source "${bash_preexec}"
  else
    printf 'Missing source file: %s\n' "${bash_preexec}" >&2
  fi

  export BASH_COMPLETION_USER_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/bash-completion"

  if ! shopt -oq posix; then
    if [ -r /usr/share/bash-completion/bash_completion ]; then
      # shellcheck source=/dev/null
      source /usr/share/bash-completion/bash_completion
    elif [ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
      # shellcheck source=/dev/null
      source /opt/homebrew/etc/profile.d/bash_completion.sh
    elif [ -r /usr/local/etc/profile.d/bash_completion.sh ]; then
      # shellcheck source=/dev/null
      source /usr/local/etc/profile.d/bash_completion.sh
    fi
  fi
fi
