# 30_keychain.sh - Keychain settings

if [ -n "${__SHELL_KEYCHAIN_LOADED:-}" ]; then
  return 0
fi
__SHELL_KEYCHAIN_LOADED=1
export __SHELL_KEYCHAIN_LOADED

# preserve ssh agent forwarding
use_forwarded_agent=false
if [ -n "${SSH_CONNECTION:-}" ] && [ -n "${SSH_AUTH_SOCK:-}" ]; then
  case "${SSH_AUTH_SOCK}" in
    /tmp/ssh-*/agent.*)
      ssh-add -l >/dev/null 2>&1
      agent_status=$?
      if [ "${agent_status}" -eq 0 ] || [ "${agent_status}" -eq 1 ]; then
        use_forwarded_agent=true
      fi
      ;;
  esac
fi

# keychain setup
if [ "${use_forwarded_agent}" != "true" ] && command -v keychain >/dev/null 2>&1 && [ -f "${HOME}/.ssh/id_ed25519" ]; then
  shell_keychain_agent_usable() {
    ssh-add -l >/dev/null 2>&1
    agent_status=$?
    [ "${agent_status}" -eq 0 ] || [ "${agent_status}" -eq 1 ]
  }

  shell_keychain_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)}"
  shell_keychain_env_file="${HOME}/.keychain/${shell_keychain_host}-env"

  case "$-" in
    *i*)
      eval "$(keychain --eval --quiet id_ed25519)" || true
      ;;
    *)
      eval "$(keychain --eval --quiet --noask id_ed25519)"
      ;;
  esac

  if ! shell_keychain_agent_usable; then
    unset SSH_AUTH_SOCK SSH_AGENT_PID
    if [ -n "${shell_keychain_env_file}" ] && [ -f "${shell_keychain_env_file}" ]; then
      rm -f "${shell_keychain_env_file}"
    fi

    case "$-" in
      *i*)
        eval "$(keychain --eval --quiet id_ed25519)" || true
        ;;
      *)
        eval "$(keychain --eval --quiet --noask id_ed25519)"
        ;;
    esac
  fi

  unset -f shell_keychain_agent_usable
  unset shell_keychain_host
  unset shell_keychain_env_file
  unset agent_status
fi
