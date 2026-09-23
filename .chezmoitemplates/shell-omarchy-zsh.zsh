# Omarchy's interactive helpers live under default/bash/fns and are not a zsh
# API. Keep the zsh surface deliberately small and native instead of sourcing
# that directory wholesale. Add a helper here only when it is useful in zsh,
# and port its semantics rather than depending on Bash compatibility modes.

# Create a tmux development layout with editor, AI, and terminal panes.
# This is the one Omarchy helper consumed by the shared ic/ix/icx aliases.
tdl() {
  if [[ -z $1 ]]; then
    print -u2 'Usage: tdl <c|cx|codex|other_ai> [<second_ai>]'
    return 1
  fi
  if [[ -z $TMUX ]]; then
    print -u2 'You must start tmux to use tdl.'
    return 1
  fi

  local current_dir=$PWD
  local editor_pane=$TMUX_PANE
  local ai=$1
  local ai2=${2:-}
  local ai_pane ai2_pane

  tmux rename-window -t "$editor_pane" "${current_dir:t}" || return
  tmux split-window -v -p 15 -t "$editor_pane" -c "$current_dir" || return

  ai_pane=$(tmux split-window -h -p 30 -t "$editor_pane" \
    -c "$current_dir" -P -F '#{pane_id}') || return

  if [[ -n $ai2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" \
      -c "$current_dir" -P -F '#{pane_id}') || return
    tmux send-keys -t "$ai2_pane" -l "$ai2"
    tmux send-keys -t "$ai2_pane" C-m
  fi

  tmux send-keys -t "$ai_pane" -l "$ai"
  tmux send-keys -t "$ai_pane" C-m
  tmux send-keys -t "$editor_pane" -l "$EDITOR ."
  tmux send-keys -t "$editor_pane" C-m
  tmux select-pane -t "$editor_pane"
}
