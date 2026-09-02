# Interactive setup shared by zsh and bash.
#
# Everything here is POSIX and parameterised on "$__shell", so the same text
# renders into both ~/.zshrc and ~/.bashrc. Anything that genuinely differs
# between the two, such as completion systems and history options, stays in the
# rc file itself rather than being smuggled in here behind a branch.
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

# micromamba's shell hook prepends $MAMBA_ROOT_PREFIX/condabin, so it has to run
# before `mise activate` rather than after. Run it after and condabin sits ahead
# of every mise tool path, which is one of the two things `mise doctor` warns
# about. micromamba is itself a mise tool, though, so PATH cannot find it yet:
# ask mise where it is. The fallback covers a host that got micromamba some
# other way, and both go quiet when neither is installed.
__micromamba=$(mise which micromamba 2>/dev/null) ||
  __micromamba=$(command -v micromamba 2>/dev/null) ||
  __micromamba=
if [ -n "$__micromamba" ]; then
  MAMBA_EXE=$__micromamba
  export MAMBA_EXE
  eval "$("$MAMBA_EXE" shell hook --shell "$__shell" --root-prefix "$MAMBA_ROOT_PREFIX")"
fi
unset __micromamba

# mise supplies node, python, go and the tools declared in its conf.d files.
# Anything below this line may depend on the tool paths it prepends; nothing
# above it can, which is why GOPATH is set in the env file and why micromamba is
# resolved through `mise which` above.
command -v mise >/dev/null 2>&1 && eval "$(mise activate "$__shell")"

if command -v fzf >/dev/null 2>&1; then
  # atuin binds Ctrl-R in the prompt block below, so fzf's history widget would
  # be bound here only to be overwritten a few lines later. An empty (but set)
  # FZF_CTRL_R_COMMAND makes fzf skip defining it at all. Ctrl-T, Alt-C and
  # completion are unaffected. Without atuin, leave fzf's Ctrl-R in place.
  command -v atuin >/dev/null 2>&1 && FZF_CTRL_R_COMMAND=
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

{{ if eq .chezmoi.os "darwin" }}
# The coding agents in ~/.config/mise/conf.d/10-dotfiles.toml sit at "latest",
# but `mise upgrade` skips global config. Refresh the untracked Mac lock, then
# install the resolved versions. MISE_MINIMUM_RELEASE_AGE=0 waives mise's
# new-release cooldown for these fast-moving CLIs.
command -v mise >/dev/null 2>&1 && alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise lock --global --bump && mise install'

# The counterpart to the drift check in run_after_darwin-rebuild.sh: that script
# only nags, because `chezmoi apply` must not escalate. This is the explicit
# command it tells you to run. The flake path is fixed at apply time from the
# source tree the alias was rendered from, so it keeps pointing at this repo
# from any directory.
command -v darwin-rebuild >/dev/null 2>&1 && alias nix-switch='sudo darwin-rebuild switch --flake {{ .chezmoi.sourceDir }}/nix#macbook'
{{- else if eq .chezmoi.os "linux" }}
# Linux commits its global lock, and the source tree holds the only copy: it is
# repo content, never applied to $HOME. Refresh it for the target platform, then
# install exactly what it resolved. Commit the result.
if command -v mise >/dev/null 2>&1; then
  mup() {
    local mise_config_dir={{ printf "%s/dot_config/mise" .chezmoi.sourceDir | quote }}

    MISE_MINIMUM_RELEASE_AGE=0 MISE_CONFIG_DIR="$mise_config_dir" \
      mise lock --global --platform linux-x64 --bump &&
      MISE_CONFIG_DIR="$mise_config_dir" mise install --locked
  }
fi
{{- end }}

command -v bun >/dev/null 2>&1 && alias bunx='bun x'
command -v emacsclient >/dev/null 2>&1 && alias emacs='emacsclient --no-window-system --alternate-editor=""'

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

if command -v docker >/dev/null 2>&1; then
  alias d='docker'
fi
command -v opencode >/dev/null 2>&1 && alias c='opencode --auto'
command -v codex >/dev/null 2>&1 && alias cy='codex --approve-for-me'
command -v tmux >/dev/null 2>&1 && alias t='tmux attach || tmux new -s main'

# Clear scrollback as well as the screen before handing the terminal over.
command -v claude >/dev/null 2>&1 &&
  alias cx='printf "\033[2J\033[3J\033[H" && claude --permission-mode auto'

# `n` with no argument opens the current directory rather than an empty buffer.
n() {
  if [ "$#" -eq 0 ]; then
    command nvim .
  else
    command nvim "$@"
  fi
}

# Linux has no `open`. Detach so the shell does not wait on the viewer.
if ! command -v open >/dev/null 2>&1 && command -v xdg-open >/dev/null 2>&1; then
  open() (
    xdg-open "$@" >/dev/null 2>&1 &
  )
fi

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

# --- omarchy ----------------------------------------------------------------

# Omarchy ships shell functions (tdl, worktrees, rsyncing, ...) with its
# desktop. They are an explicitly Bash-owned interface, so only Bash sources
# them. zsh gets the small, native adapter in shell-omarchy-zsh.zsh instead;
# sourcing these files in zsh happened to work until a function used different
# array indexing or `read` semantics, and any upstream addition could break it
# again.
#
# Three roots, for the same reasons .chezmoitemplates/omarchy-detect.tmpl
# checks three: OMARCHY_PATH is what `omarchy dev link` repoints, but it is
# exported only by shells that ran Omarchy's env-bootstrap and this file
# replaces the ~/.bashrc that used to run it; Omarchy 4 packages the desktop
# into /usr/share/omarchy; Omarchy 3 used a clone in the home directory.
# Omarchy 4 also moved the functions from default/fns to default/bash/fns, so
# each root is tried in both layouts. First directory that exists wins.
if [ "$__shell" = bash ]; then
  for __dir in \
    "${OMARCHY_PATH:-}/default/bash/fns" \
    "${OMARCHY_PATH:-}/default/fns" \
    /usr/share/omarchy/default/bash/fns \
    /usr/share/omarchy/default/fns \
    "$HOME/.local/share/omarchy/default/bash/fns" \
    "$HOME/.local/share/omarchy/default/fns"; do
    [ -d "$__dir" ] || continue
    for __fn in "$__dir"/*; do
      [ -f "$__fn" ] && [ -r "$__fn" ] && . "$__fn"
    done
    break
  done
  unset __dir __fn
fi

# Omarchy's own tools, aliased as default/bash/aliases does. Only these three:
# the rest of that file collides with the aliases above, since its `c` passes
# --auto, its `cx` a different permission mode, and it points `cd` at a zoxide
# wrapper that fights `zoxide init --cmd cd`. Where the two disagree this repo
# keeps its own. tdl is a function from the fns sourced just above, so these
# have to come after that loop.
command -v herdr >/dev/null 2>&1 && alias h='herdr'
command -v omarchy-agent >/dev/null 2>&1 && alias a='omarchy-agent --inline'
if command -v tdl >/dev/null 2>&1; then
  alias ic='tdl c'
  alias ix='tdl cx'
  alias icx='tdl c cx'
fi

# --- local overrides --------------------------------------------------------

# Tracked but encrypted. Rendered from
# dot_config/shell/encrypted_private_secrets.sh.age, and skipped entirely when
# the age identity is absent (see .chezmoiignore.tmpl).
[ -f "$XDG_CONFIG_HOME/shell/secrets.sh" ] && . "$XDG_CONFIG_HOME/shell/secrets.sh"

# Machine-local escape hatch. Nothing in this repo creates or manages this
# file: write it by hand on a host that needs something the tracked config
# should not carry, and keep it out of version control. This is where a
# per-machine JUPYTER_PORT or MAMBA_ROOT_PREFIX override belongs.
[ -f "$XDG_CONFIG_HOME/shell/extras.sh" ] && . "$XDG_CONFIG_HOME/shell/extras.sh"

# --- prompt (must stay last) ------------------------------------------------

command -v starship >/dev/null 2>&1 && eval "$(starship init "$__shell")"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init --cmd cd "$__shell")"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init "$__shell")"

unset __shell
