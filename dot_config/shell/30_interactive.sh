# 30_interactive.sh - aliases, hooks, and completions for interactive shells
# shellcheck shell=bash

if command -v bun >/dev/null 2>&1; then
  alias bunx="bun x"
fi

if [ -n "${SHELL_NAME:-}" ] && command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook "${SHELL_NAME}")"
fi

if [ -n "${SHELL_NAME:-}" ] && command -v mise >/dev/null 2>&1; then
  eval "$(mise activate "${SHELL_NAME}")"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if command -v fzf >/dev/null 2>&1 && command -v bat >/dev/null 2>&1; then
  alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
  alias eff='${EDITOR:-nvim} "$(ff)"'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

if command -v docker >/dev/null 2>&1; then
  alias d='docker'
fi

n() {
  if [ "$#" -eq 0 ]; then
    command nvim .
  else
    command nvim "$@"
  fi
}

if [ "${SHELL_HAS_TTY:-0}" = "1" ] && command -v fzf >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  case "${SHELL_NAME:-}" in
  zsh) source <(fzf --zsh) ;;
  bash) eval "$(fzf --bash)" ;;
  esac
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
  fi
fi

if [ -n "${SHELL_NAME:-}" ] && command -v pixi >/dev/null 2>&1; then
  eval "$(pixi completion --shell "${SHELL_NAME}")"
fi

google_cloud_sdk_path="${HOME}/.local/opt/google-cloud-sdk"
if [ -n "${SHELL_NAME:-}" ]; then
  gcloud_shell_completion_path="${google_cloud_sdk_path}/completion.${SHELL_NAME}.inc"
  shell_source_if_exists "${gcloud_shell_completion_path}"
fi
