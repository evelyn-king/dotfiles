# 99_finish.sh - close up commands

shell_config_hook_shell="${ZSH_VERSION:+zsh}"
shell_config_hook_shell="${shell_config_hook_shell:-bash}"

# starship at end
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init "${shell_config_hook_shell}")"
fi

# zoxide works best at end
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init "${shell_config_hook_shell}")"
fi

# Bash needs bash-preexec for atuin's hooks.
if [ "${shell_config_hook_shell}" = "bash" ] && [ -f "${HOME}/.bash-preexec.sh" ]; then
  . "${HOME}/.bash-preexec.sh"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init "${shell_config_hook_shell}")"
fi

unset shell_config_hook_shell
