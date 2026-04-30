# 25_nvim.sh - add chezmoi-managed Neovim to PATH
# shellcheck shell=bash

if [ -d "${HOME}/.local/opt/nvim/bin" ]; then
  shell_path_prepend "${HOME}/.local/opt/nvim/bin"
fi
