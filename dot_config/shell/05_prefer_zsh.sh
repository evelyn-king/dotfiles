# 05_prefer_zsh.sh - optional zsh handoff from bash

shell_should_prefer_zsh() {
  [ "${SHELL_PREFER_ZSH:-0}" = "1" ] || return 1
  [ -n "${BASH_VERSION:-}" ] || return 1
  [ -z "${ZSH_VERSION:-}" ] || return 1

  case "$-" in
    *i*) ;;
    *)
      return 1
      ;;
  esac

  command -v zsh >/dev/null 2>&1 || return 1
}

shell_exec_preferred_zsh() {
  shell_should_prefer_zsh || return 0
  exec zsh "$@"
}
