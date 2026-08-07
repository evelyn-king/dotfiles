# 45_omarchy.sh - Omarchy interactive shell integration
# shellcheck shell=bash

if [ "${SHELL_IS_INTERACTIVE:-0}" != "1" ] || [ "${SHELL_IS_OMARCHY:-0}" != "1" ]; then
  return 0
fi

omarchy_root="${OMARCHY_PATH:-${HOME}/.local/share/omarchy}"

# Omarchy 4 moved the shell functions from default/fns to default/bash/fns.
# Check both so machines on either version keep tdl, worktrees, rsyncing, etc.
for omarchy_function_path in "${omarchy_root}/default/bash/fns" "${omarchy_root}/default/fns"; do
  if [ -d "${omarchy_function_path}" ]; then
    for file in "${omarchy_function_path}"/*; do
      if [ -f "${file}" ] && [ -r "${file}" ]; then
        # shellcheck source=/dev/null
        . "${file}"
      fi
    done
    break
  fi
done
unset omarchy_root omarchy_function_path
