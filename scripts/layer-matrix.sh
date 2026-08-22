#!/usr/bin/env bash
#
# Resolve the layer set for machines you are not sitting at.
#
#   ./scripts/layer-matrix.sh            # every scenario
#   ./scripts/layer-matrix.sh ubuntu-noroot
#   ./scripts/layer-matrix.sh --update   # refresh expected output and docs
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

. scripts/layer-scenarios.sh

GOLDEN="scripts/layer-matrix.golden"
LAYERS_DOC="docs/layers.md"
BEGIN_MARKER="<!-- BEGIN GENERATED LAYER MATRIX -->"
END_MARKER="<!-- END GENERATED LAYER MATRIX -->"

render() {
  local os="$1" id="$2" idlike="$3" root="$4" libc="$5" desktop="$6" present="$7"

  local probes="" b
  for b in $LAYER_PROBE_BINARIES; do
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

render_matrix() {
  local want="$1" status=0 matched=0
  local name os id idlike root libc desktop present out

  while IFS='|' read -r name os id idlike root libc desktop present; do
    [ -n "$name" ] || continue
    [ -z "$want" ] || [ "$want" = "$name" ] || continue
    matched=1
    # A template error prints to stderr and yields an empty line, which is easy
    # to skim past. Treat it as the failure it is.
    if ! out=$(render "$os" "$id" "$idlike" "$root" "$libc" "$desktop" "$present") || [ -z "$out" ]; then
      printf '%-22s !! resolution failed\n' "$name"
      status=1
      continue
    fi
    printf '%-22s %s\n' "$name" "$out"
  done < <(layer_scenarios)

  if [ "$matched" -eq 0 ]; then
    printf 'unknown scenario: %s\n' "$want" >&2
    return 2
  fi
  return "$status"
}

update_layers_doc() {
  local matrix="$1" output="$2"

  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v matrix="$matrix" '
    BEGIN {
      while ((getline line < matrix) > 0) rendered = rendered line "\n"
      close(matrix)
    }
    $0 == begin {
      begins++
      print
      print "```"
      print "$ ./scripts/layer-matrix.sh"
      printf "%s", rendered
      print "```"
      replacing = 1
      next
    }
    $0 == end {
      ends++
      replacing = 0
      print
      next
    }
    !replacing { print }
    END {
      if (begins != 1 || ends != 1 || replacing) exit 1
    }
  ' "$LAYERS_DOC" >"$output"
}

usage() {
  printf 'usage: %s [scenario | --update]\n' "$0" >&2
}

want=""
update=0
case "$#" in
0) ;;
1)
  if [ "$1" = "--update" ]; then
    update=1
  else
    want="$1"
  fi
  ;;
*)
  usage
  exit 2
  ;;
esac

actual=$(mktemp "${TMPDIR:-/tmp}/layer-matrix.XXXXXX")
expected="$GOLDEN"
expected_output=""
doc_output=""
trap 'rm -f "$actual" ${expected_output:+"$expected_output"} ${doc_output:+"$doc_output"}' EXIT

if ! render_matrix "$want" >"$actual"; then
  sed -n '1,$p' "$actual"
  exit 1
fi

if [ "$update" -eq 1 ]; then
  doc_output=$(mktemp "${TMPDIR:-/tmp}/layer-matrix-doc.XXXXXX")
  if ! update_layers_doc "$actual" "$doc_output"; then
    printf 'could not replace the generated matrix in %s\n' "$LAYERS_DOC" >&2
    exit 1
  fi
  chmod 0644 "$actual" "$doc_output"
  mv "$actual" "$GOLDEN"
  mv "$doc_output" "$LAYERS_DOC"
  sed -n '1,$p' "$GOLDEN"
  exit 0
fi

if [ -n "$want" ]; then
  expected_output=$(mktemp "${TMPDIR:-/tmp}/layer-matrix-expected.XXXXXX")
  awk -v want="$want" '$1 == want { print }' "$GOLDEN" >"$expected_output"
  expected="$expected_output"
fi

if ! diff -u "$expected" "$actual"; then
  exit 1
fi
sed -n '1,$p' "$actual"
