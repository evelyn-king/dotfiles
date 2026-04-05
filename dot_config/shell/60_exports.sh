# 60_exports.sh - shell exports

if [[ "${SHELL_CONFIG_STAGE:-common}" == "interactive" && "${SHELL_IS_OMARCHY:-0}" == "1" ]]; then
  # Omarchy helpers are only needed in interactive shells.
  omarchy_function_path="${OMARCHY_PATH:-${HOME}/.local/share/omarchy}/default/fns"
  if [ -d "${omarchy_function_path}" ]; then
    for file in "${omarchy_function_path}"/*; do
      if [ -f "${file}" ] && [ -r "${file}" ]; then
        . "${file}"
      fi
    done
  fi
fi
