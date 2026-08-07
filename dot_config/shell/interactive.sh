# interactive.sh - shell config sourced by interactive bash/zsh entrypoints
# shellcheck shell=bash

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
  return 0
fi

shell_base="${XDG_CONFIG_HOME:-${HOME}/.config}/shell/base.sh"

if [ -f "${shell_base}" ]; then
  # shellcheck source=/dev/null
  . "${shell_base}"
else
  printf 'Missing source file: %s\n' "${shell_base}" >&2
  return 0
fi

if [ "${SHELL_IS_INTERACTIVE:-0}" != "1" ]; then
  return 0
fi

if [ -n "${__SHELL_INTERACTIVE_SOURCED:-}" ]; then
  return 0
fi

__SHELL_INTERACTIVE_SOURCED=1

if [ "${SHELL_NAME:-}" = "zsh" ]; then
  shell_source_or_warn "${SHELL_CONFIG_HOME}/05_zsh_completions.sh"
fi

if [ "${SHELL_NAME:-}" = "bash" ]; then
  shell_source_or_warn "${SHELL_CONFIG_HOME}/10_bash_init.sh"
fi

shell_source_or_warn "${SHELL_CONFIG_HOME}/30_interactive.sh"
shell_source_or_warn "${SHELL_CONFIG_HOME}/35_keychain.sh"
if [ "${SHELL_IS_OMARCHY:-0}" = "1" ]; then
  shell_source_or_warn "${SHELL_CONFIG_HOME}/45_omarchy.sh"
fi
shell_profile_extras="${SHELL_CONFIG_HOME}/${SHELL_PROFILE:-default}/90_extras.sh"
if [ -f "${shell_profile_extras}" ]; then
  # shellcheck source=/dev/null
  . "${shell_profile_extras}"
fi
unset shell_profile_extras

shell_source_or_warn "${SHELL_CONFIG_HOME}/99_finish.sh"
