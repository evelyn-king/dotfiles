# 99_finish.sh - shell init that should run last
# shellcheck shell=bash

if [ "${SHELL_IS_INTERACTIVE:-0}" = "1" ] && [ -n "${SHELL_NAME:-}" ] &&
  command -v starship >/dev/null 2>&1; then
  eval "$(starship init "${SHELL_NAME}")"
fi

if [ "${SHELL_IS_INTERACTIVE:-0}" = "1" ] && [ -n "${SHELL_NAME:-}" ] &&
  command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd "${SHELL_NAME}")"
fi

if [ "${SHELL_IS_INTERACTIVE:-0}" = "1" ] && [ -n "${SHELL_NAME:-}" ] &&
  command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init "${SHELL_NAME}")"
fi
