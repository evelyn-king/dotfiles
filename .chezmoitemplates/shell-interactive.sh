# Interactive setup shared by zsh and bash.
#
# Everything here is POSIX and parameterised on "$__shell", so the same text
# renders into both ~/.zshrc and ~/.bashrc. Anything that genuinely differs
# between the two — completion systems, history options — stays in the rc file
# itself rather than being smuggled in here behind a branch.
#
# Tool presence is checked at runtime, not at apply time: this branch assumes
# you install what you want and the config adapts to what it finds.

if [ -n "${ZSH_VERSION:-}" ]; then
  __shell=zsh
else
  __shell=bash
fi

GPG_TTY=$(tty 2>/dev/null) && export GPG_TTY

# --- ssh agent --------------------------------------------------------------

# Keep a forwarded agent when SSH'd in; otherwise let keychain manage a local one.
__use_forwarded_agent=0
if [ -n "${SSH_CONNECTION:-}" ]; then
  case "${SSH_AUTH_SOCK:-}" in
  /tmp/ssh-*/agent.*)
    # 0 = keys listed, 1 = agent reachable but holding none. Both are usable.
    ssh-add -l >/dev/null 2>&1
    [ $? -le 1 ] && __use_forwarded_agent=1
    ;;
  esac
fi
if [ "$__use_forwarded_agent" -eq 0 ] && command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --ignore-missing id_ed25519)" || true
fi
unset __use_forwarded_agent

# --- tool integrations ------------------------------------------------------

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook "$__shell")"
command -v pixi >/dev/null 2>&1 && eval "$(pixi completion --shell "$__shell")"

# mise supplies node, python, go and every global CLI tool — see
# ~/.config/mise/conf.d/10-dotfiles.toml. Anything below this line may depend
# on it;
# nothing above it can, which is why GOPATH is set in the env file.
command -v mise >/dev/null 2>&1 && eval "$(mise activate "$__shell")"

if command -v micromamba >/dev/null 2>&1; then
  MAMBA_EXE=$(command -v micromamba)
  export MAMBA_EXE
  eval "$("$MAMBA_EXE" shell hook --shell "$__shell" --root-prefix "$MAMBA_ROOT_PREFIX")"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --"$__shell")"
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# --- aliases and functions --------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# The coding agents in ~/.config/mise/conf.d/10-dotfiles.toml sit at "latest",
# and mise keeps no lockfile for global config, so this is what pulls them
# forward. MISE_MINIMUM_RELEASE_AGE=0 waives mise's new-release cooldown, which
# would otherwise hold back exactly the fast-moving CLIs this is for.
command -v mise >/dev/null 2>&1 && alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'

command -v bun >/dev/null 2>&1 && alias bunx='bun x'
command -v docker >/dev/null 2>&1 && alias d='docker'
command -v rails >/dev/null 2>&1 && alias r='rails'
command -v opencode >/dev/null 2>&1 && alias c='opencode'
command -v tmux >/dev/null 2>&1 && alias t='tmux attach || tmux new -s Work'
command -v emacsclient >/dev/null 2>&1 && alias emacs='emacsclient --no-window-system --alternate-editor=""'
command -v claude >/dev/null 2>&1 && alias cx='printf "\033[2J\033[3J\033[H" && claude --allow-dangerously-skip-permissions'

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

if command -v git >/dev/null 2>&1; then
  alias g='git'
  alias gcm='git commit -m'
  alias gcam='git commit -a -m'
  alias gcad='git commit -a --amend'
fi

n() {
  if [ $# -eq 0 ]; then
    command nvim .
  else
    command nvim "$@"
  fi
}

create_direnv_micromamba() {
  env_name=${1:-${PWD##*/}}
  echo "layout micromamba $env_name" >.envrc
  unset env_name
  direnv allow .
}

create_direnv_venv() {
  echo "source .venv/bin/activate" >.envrc
  direnv allow .
}

jupyter_remote_load_env() {
  env_file=${1:-$JUPYTER_REMOTE_ENV_FILE}
  if [ ! -f "$env_file" ]; then
    printf 'Missing Jupyter env file: %s\n' "$env_file" >&2
    unset env_file
    return 1
  fi
  . "$env_file"
  unset env_file
}

# --- local overrides --------------------------------------------------------

[ -f "$XDG_CONFIG_HOME/shell/extras.sh" ] && . "$XDG_CONFIG_HOME/shell/extras.sh"

# --- prompt (must stay last) ------------------------------------------------

command -v starship >/dev/null 2>&1 && eval "$(starship init "$__shell")"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init --cmd cd "$__shell")"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init "$__shell")"

unset __shell
