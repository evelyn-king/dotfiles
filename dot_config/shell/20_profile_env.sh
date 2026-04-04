# 20_profile_env.sh - POSIX-safe login environment

if [ -n "${__SHELL_PROFILE_ENV_LOADED:-}" ]; then
  return 0
fi
__SHELL_PROFILE_ENV_LOADED=1
export __SHELL_PROFILE_ENV_LOADED

shell_path_prepend() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *) PATH="$1:${PATH}" ;;
  esac
}

shell_path_append() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *) PATH="${PATH}:$1" ;;
  esac
}

export EDITOR="nvim"
export VISUAL="${EDITOR}"
export SUDO_EDITOR="${EDITOR}"
export SHELL_OS="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
export SHELL_HOSTNAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"

if [ -t 0 ] || [ -t 1 ] || [ -t 2 ]; then
  GPG_TTY="$(tty 2>/dev/null)"
  if [ -n "${GPG_TTY}" ]; then
    export GPG_TTY
  fi
fi

export BAT_THEME="ansi"
case "${SHELL_OS}:${SHELL_HOSTNAME}" in
  linux:gimli|linux:maxwell)
    export SHELL_IS_OMARCHY=1
    export OMARCHY_PATH="${HOME}/.local/share/omarchy"
    shell_path_prepend "${OMARCHY_PATH}/bin"
    ;;
  *)
    export SHELL_IS_OMARCHY=0
    ;;
esac

shell_path_append "${HOME}/.local/bin"
export PATH

export NLTK_DATA="${HOME}/.local/share/nltk_data"

if [ -f "${HOME}/.local/share/../bin/env" ]; then
  . "${HOME}/.local/share/../bin/env"
fi

if [ -f "${HOME}/.cargo/env" ]; then
  . "${HOME}/.cargo/env"
fi

if [ -f "${HOME}/.config/emacs/bin/doom" ]; then
  shell_path_prepend "${HOME}/.config/emacs/bin"
fi

if [ -d "${HOME}/.bun/bin" ]; then
  shell_path_prepend "${HOME}/.bun/bin"
fi

if [ -d "${HOME}/.cache/.bun/bin" ]; then
  shell_path_prepend "${HOME}/.cache/.bun/bin"
fi

if [ -f "${HOME}/.pixi/bin/pixi" ]; then
  shell_path_append "${HOME}/.pixi/bin"
fi

export PATH

unset -f shell_path_prepend
unset -f shell_path_append
