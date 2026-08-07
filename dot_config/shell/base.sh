# base.sh - shell config sourced by every bash/zsh startup entrypoint
# shellcheck shell=bash

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
  return 0
fi

if [ -n "${__SHELL_BASE_SOURCED:-}" ]; then
  return 0
fi

__SHELL_BASE_SOURCED=1

shell_lib="${XDG_CONFIG_HOME:-${HOME}/.config}/shell/lib.sh"

if [ -f "${shell_lib}" ]; then
  # shellcheck source=/dev/null
  . "${shell_lib}"
else
  printf 'Missing source file: %s\n' "${shell_lib}" >&2
  return 0
fi

shell_source_or_warn "${SHELL_CONFIG_HOME}/00_init.sh"
shell_source_or_warn "${SHELL_CONFIG_HOME}/15_host_env.sh"
shell_source_or_warn "${SHELL_CONFIG_HOME}/25_nvim.sh"
shell_source_or_warn "${SHELL_CONFIG_HOME}/30_env.sh"
shell_source_or_warn "${SHELL_CONFIG_HOME}/40_python.sh"
