#!/bin/sh

# Shared synthetic machine contexts for the layer checks.
#
# name | os | os-release id | id_like | root | libc | desktop | present binaries
layer_scenarios() {
  cat <<'EOF'
ubuntu-noroot|linux|ubuntu|debian|false|glibc|false|apt-get
ubuntu-noroot-tooled|linux|ubuntu|debian|false|glibc|false|apt-get mise cargo
ubuntu-root|linux|ubuntu|debian|true|glibc|false|apt-get mise
ubuntu-desktop|linux|ubuntu|debian|true|glibc|true|apt-get mise cargo emacs
alpine-noroot|linux|alpine||false|musl|false|
nixos-server|linux|nixos||true|glibc|false|nix mise
omarchy|linux|omarchy|arch|true|glibc|true|nix mise cargo rustup emacs micromamba
macbook|darwin|||false|none|true|nix darwin-rebuild mise cargo rustup emacs micromamba
ci-container|linux|debian|debian|true|glibc|false|
EOF
}

# Every binary probed by a layer. A scenario's list is a whitelist, so the
# checks force every binary absent before enabling the listed ones.
LAYER_PROBE_BINARIES="apt-get nix nix-env darwin-rebuild mise cargo rustup emacs emacsclient micromamba mamba conda"

layer_scenario() {
  layer_scenarios |
    awk -F '|' -v want="$1" '$1 == want { print; found = 1 } END { exit !found }'
}

layer_scenario_config() (
  config_repo=$1
  config_root=$2
  config_libc=$3
  config_desktop=$4
  config_present=$5
  config_repo=$(printf '%s' "$config_repo" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf 'sourceDir = "%s"\n\n' "$config_repo"
  printf '[data]\n'
  printf 'layerForce = []\n'
  printf 'layerDisable = []\n\n'
  printf '[data.facts]\n'
  printf 'root = %s\n' "$config_root"
  printf 'libc = "%s"\n' "$config_libc"
  printf 'desktop = %s\n' "$config_desktop"
  printf 'prefixWritable = true\n\n'
  printf '[data.layerProbes]\n'
  for binary in $LAYER_PROBE_BINARIES; do
    value=false
    case " $config_present " in
    *" $binary "*) value=true ;;
    esac
    printf '"%s" = %s\n' "$binary" "$value"
  done
)
