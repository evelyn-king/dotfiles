# 80_misc.sh - interactive shell hooks

if [[ "${SHELL_CONFIG_STAGE:-interactive}" == "interactive" ]]; then
  shell_config_hook_shell="${ZSH_VERSION:+zsh}"
  shell_config_hook_shell="${shell_config_hook_shell:-bash}"

  # These rely on shell hooks rather than plain environment exports.
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "${shell_config_hook_shell}")"
  fi

  if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook "${shell_config_hook_shell}")"
  fi

  unset shell_config_hook_shell
fi
