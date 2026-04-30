# 45_omarchy.sh - Omarchy interactive shell integration
# shellcheck shell=bash

if [ "${SHELL_IS_INTERACTIVE:-0}" != "1" ] || [ "${SHELL_IS_OMARCHY:-0}" != "1" ]; then
  return 0
fi

omarchy_function_path="${OMARCHY_PATH:-${HOME}/.local/share/omarchy}/default/fns"
if [ -d "${omarchy_function_path}" ]; then
  for file in "${omarchy_function_path}"/*; do
    if [ -f "${file}" ] && [ -r "${file}" ]; then
      # shellcheck source=/dev/null
      . "${file}"
    fi
  done
fi
unset omarchy_function_path
