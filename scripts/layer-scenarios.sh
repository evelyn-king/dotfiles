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
# shellcheck disable=SC2034 # Used by scripts that source this file.
LAYER_PROBE_BINARIES="apt-get nix nix-env darwin-rebuild mise cargo rustup emacs emacsclient micromamba mamba conda"
