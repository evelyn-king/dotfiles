# 30_env.sh - non-interactive-safe tool and PATH setup
# shellcheck shell=bash

if [ "$(uname -s)" = "Darwin" ]; then
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  elif [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if [ -d "${HOME}/.local/opt/go/bin" ]; then
  shell_path_prepend "${HOME}/.local/opt/go/bin"
fi

if command -v go >/dev/null 2>&1; then
  export GOPATH="${XDG_DATA_HOME}/go"
  shell_path_prepend "${GOPATH}/bin"
fi

if [ -d "${HOME}/.rd/bin" ]; then
  shell_path_prepend "${HOME}/.rd/bin"
fi

if [ -d "${HOME}/.config/emacs/bin" ]; then
  shell_path_prepend "${HOME}/.config/emacs/bin"
fi

if [ -d "${HOME}/.pixi/bin" ]; then
  shell_path_append "${HOME}/.pixi/bin"
fi

if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Obsidian.app/Contents/MacOS" ]; then
  shell_path_append "/Applications/Obsidian.app/Contents/MacOS"
fi

shell_source_if_exists "${HOME}/.cargo/env"

google_cloud_sdk_path="${HOME}/.local/opt/google-cloud-sdk"
if [ -n "${SHELL_NAME:-}" ]; then
  shell_source_if_exists "${google_cloud_sdk_path}/path.${SHELL_NAME}.inc"
fi

# nvm
NVM_DIR="${HOME}/.config/nvm"
if [ -d "${NVM_DIR}" ]; then
  export NVM_DIR
  shell_source_if_exists "${NVM_DIR}/nvm.sh"
  shell_source_if_exists "${NVM_DIR}/bash_completion"
fi

shell_source_if_exists "${HOME}/.atuin/bin/env"
