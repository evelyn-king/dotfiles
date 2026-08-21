#!/usr/bin/env bash
#
# Resolve the layer set for machines you are not sitting at.
#
#   ./scripts/layer-matrix.sh            # every scenario
#   ./scripts/layer-matrix.sh ubuntu-noroot
#
# Each scenario is a synthetic template context fed to
# .chezmoitemplates/layers.yaml.tmpl in place of the real one. `chezmoi` is the
# only dependency: no jq, no python, because this has to run on the same
# stripped-down boxes the standalone layer targets.
#
# This is the regression test for .chezmoidata/layers.yaml. A layer whose
# predicate is subtly wrong shows up here as a machine gaining or losing a
# layer it should not have, which is far cheaper to notice than discovering it
# on the box itself.

set -euo pipefail

cd "$(dirname "$0")/.."

# name | os | os-release id | id_like | root | libc | desktop | present binaries
#
# "present binaries" is the whitelist: anything named in layers.yaml and absent
# from this list is forced to look missing, so a scenario describes a machine
# completely rather than inheriting stray tools from the host running the test.
scenarios() {
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

# Every binary any layer might probe. Each is set false, then the scenario's
# own list flips its entries true.
ALL_BINARIES="apt-get nix nix-env darwin-rebuild mise cargo rustup emacs emacsclient micromamba mamba conda"

render() {
  local os="$1" id="$2" idlike="$3" root="$4" libc="$5" desktop="$6" present="$7"

  local probes="" b
  for b in $ALL_BINARIES; do
    case " $present " in
    *" $b "*) probes="$probes \"$b\" true" ;;
    *) probes="$probes \"$b\" false" ;;
    esac
  done

  # os-release keys are omitted entirely when empty rather than set to "",
  # because that is what chezmoi does on darwin and the resolver's hasKey
  # guards are exactly what this needs to exercise.
  local osrel="dict"
  [ -n "$id" ] && osrel="$osrel \"id\" \"$id\""
  [ -n "$idlike" ] && osrel="$osrel \"idLike\" \"$idlike\""

  chezmoi execute-template "{{ includeTemplate \"layers.yaml.tmpl\" (dict
      \"chezmoi\" (dict \"os\" \"$os\" \"osRelease\" ($osrel))
      \"facts\" (dict \"root\" $root \"libc\" \"$libc\" \"desktop\" $desktop \"prefixWritable\" true)
      \"layers\" .layers
      \"layerProbes\" (dict$probes)) }}" |
    sed -n 's/^names: //p'
}

want="${1:-}"
status=0
while IFS='|' read -r name os id idlike root libc desktop present; do
  [ -n "$name" ] || continue
  [ -z "$want" ] || [ "$want" = "$name" ] || continue
  # A template error prints to stderr and yields an empty line, which is easy
  # to skim past. Treat it as the failure it is.
  if ! out=$(render "$os" "$id" "$idlike" "$root" "$libc" "$desktop" "$present") || [ -z "$out" ]; then
    printf '%-22s !! resolution failed\n' "$name"
    status=1
    continue
  fi
  printf '%-22s %s\n' "$name" "$out"
done < <(scenarios)
exit $status
