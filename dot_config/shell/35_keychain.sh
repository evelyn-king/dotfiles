# 35_keychain.sh - keychain setup
# shellcheck shell=bash

if [ -n "${__SHELL_KEYCHAIN_LOADED:-}" ]; then
  return 0
fi
__SHELL_KEYCHAIN_LOADED=1
export __SHELL_KEYCHAIN_LOADED

# Preserve SSH agent forwarding in remote sessions.
# If SSH provided a valid forwarded agent socket, keep it instead of overriding
# SSH_AUTH_SOCK with a local keychain-managed agent.
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
if [ "${use_forwarded_agent}" != "true" ] && command -v keychain >/dev/null 2>&1; then
  case "$-" in
  *i*)
    eval "$(keychain --eval --quiet --ignore-missing id_ed25519)" || true
    ;;
  *)
    eval "$(keychain --eval --quiet --noask --ignore-missing id_ed25519)" || true
    ;;
  esac
fi
