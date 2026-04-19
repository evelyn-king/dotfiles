# 80_misc.sh - interactive shell hooks

if [[ "${SHELL_CONFIG_STAGE:-interactive}" == "interactive" ]]; then
  shell_config_hook_shell="${ZSH_VERSION:+zsh}"
  shell_config_hook_shell="${shell_config_hook_shell:-bash}"
  
  # The next line updates PATH for the Google Cloud SDK.
  if [ -f "${HOME}/.local/opt/google-cloud-sdk/path.bash.inc" ]; then
    . "${HOME}/.local/opt/google-cloud-sdk/path.bash.inc"
  fi

  # The next line enables shell command completion for gcloud.
  if [ -f "${HOME}/.local/opt/google-cloud-sdk/completion.bash.inc" ]; then
    . "${HOME}/.local/opt/google-cloud-sdk/completion.bash.inc"
  fi
 
 # These rely on shell hooks rather than plain environment exports.
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "${shell_config_hook_shell}")"
  fi

  if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook "${shell_config_hook_shell}")"
  fi

  unset shell_config_hook_shell
fi
