# lib.sh - shared shell startup helpers
# shellcheck shell=bash

if [ -n "${__SHELL_LIB_SOURCED:-}" ]; then
  return 0
fi

__SHELL_LIB_SOURCED=1

SHELL_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}/shell"
export SHELL_CONFIG_HOME

shell_source_or_warn() {
  local file="$1"

  if [ -f "${file}" ]; then
    # shellcheck source=/dev/null
    . "${file}"
  else
    printf 'Missing source file: %s\n' "${file}" >&2
  fi
}

shell_source_if_exists() {
  local file="$1"

  if [ -f "${file}" ]; then
    # shellcheck source=/dev/null
    . "${file}"
  fi
}

shell_path_prepend() {
  local dir="$1"

  [ -n "${dir}" ] || return 0
  case ":${PATH:-}:" in
  *:"${dir}":*) ;;
  *)
    PATH="${dir}${PATH:+:${PATH}}"
    export PATH
    ;;
  esac
}

shell_path_append() {
  local dir="$1"

  [ -n "${dir}" ] || return 0
  case ":${PATH:-}:" in
  *:"${dir}":*) ;;
  *)
    PATH="${PATH:+${PATH}:}${dir}"
    export PATH
    ;;
  esac
}

if [ -n "${ZSH_VERSION:-}" ]; then
  SHELL_NAME='zsh'
elif [ -n "${BASH_VERSION:-}" ]; then
  SHELL_NAME='bash'
else
  SHELL_NAME=''
fi
export SHELL_NAME

case "$-" in
*i*) SHELL_IS_INTERACTIVE=1 ;;
*) SHELL_IS_INTERACTIVE=0 ;;
esac
export SHELL_IS_INTERACTIVE

if [ -t 0 ] || [ -t 1 ] || [ -t 2 ]; then
  SHELL_HAS_TTY=1
else
  SHELL_HAS_TTY=0
fi
export SHELL_HAS_TTY
