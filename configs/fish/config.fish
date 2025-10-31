if status is-interactive
    # Commands to run in interactive sessions can go here
    thefuck --alias | source
    starship init fish | source
end

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'micromamba shell init' !!
set -gx MAMBA_EXE "/Users/evelynking/.local/bin/micromamba"
set -gx MAMBA_ROOT_PREFIX "/Users/evelynking/.local/opt/micromamba"
$MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
# <<< mamba initialize <<<

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
set --export --prepend PATH "/Users/evelynking/.rd/bin"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
