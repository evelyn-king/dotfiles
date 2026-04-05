# 10_init.sh - start up config

# History config
if [ -n "${BASH_VERSION:-}" ]; then
  shopt -s histappend
  HISTCONTROL=ignoreboth
  HISTSIZE=32768
  HISTFILESIZE="${HISTSIZE}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  setopt APPEND_HISTORY HIST_IGNORE_ALL_DUPS
  HISTSIZE=32768
  SAVEHIST="${HISTSIZE}"
fi

# Ensure command hashing is off for mise
set +h 2>/dev/null || true
