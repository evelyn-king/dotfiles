# 05_zsh_completions.sh - init zsh completions

if [[ -n "${ZSH_VERSION:-}" && "${SHELL_IS_INTERACTIVE:-0}" = "1" ]]; then
  local_zsh_functions="${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions"
  if [[ -d "${local_zsh_functions}" ]]; then
    case " ${fpath[*]} " in
      *" ${local_zsh_functions} "*) ;;
      *) fpath=("${local_zsh_functions}" "${fpath[@]}") ;;
    esac
  fi
  autoload -Uz compinit
  for dump in ~/.zcompdump(N.mh+24); do
    compinit
  done
  compinit -C
  autoload -U +X bashcompinit && bashcompinit
fi
