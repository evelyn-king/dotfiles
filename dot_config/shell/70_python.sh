# 70_python.sh - interactive Python shell features

shell_config_hook_shell="${ZSH_VERSION:+zsh}"
shell_config_hook_shell="${shell_config_hook_shell:-bash}"

if [[ "${SHELL_CONFIG_STAGE:-interactive}" == "interactive" ]]; then
  if [ -n "${MAMBA_EXE:-}" ]; then
    eval "$(${MAMBA_EXE} shell hook --shell "${shell_config_hook_shell}" --root-prefix "${MAMBA_ROOT_PREFIX}")"
  elif [ -f "${HOME}/.local/opt/mambaforge/etc/profile.d/conda.sh" ]; then
    if [ "${shell_config_hook_shell}" = "zsh" ]; then
      eval "$("${HOME}/.local/opt/mambaforge/bin/conda" shell.zsh hook)"
    else
      eval "$("${HOME}/.local/opt/mambaforge/bin/conda" shell.bash hook)"
    fi
    . "${HOME}/.local/opt/mambaforge/etc/profile.d/conda.sh"
  elif [ -f "${HOME}/.local/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    . "${HOME}/.local/opt/miniconda3/etc/profile.d/conda.sh"
  fi

  if [ -f "${HOME}/.pixi/bin/pixi" ]; then
    eval "$(pixi completion --shell "${shell_config_hook_shell}")"
  fi
fi

unset shell_config_hook_shell
