#!/bin/sh

# Check the layer schema and ownership declarations without adding a YAML
# parser. Chezmoi flattens the data into records and resolves source names.

set -eu

repo=$(
  unset CDPATH
  cd "$(dirname "$0")/.."
  pwd
)
cd "$repo"

work=$(mktemp -d "${TMPDIR:-/tmp}/layer-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
records="$work/records"
managed_paths="$work/managed-paths"
managed_scripts="$work/managed-scripts"
resolved_owners="$work/resolved-owners"

chezmoi execute-template -S "$repo" \
  '{{ includeTemplate "layer-lint-records.tmpl" . }}' >"$records"

if ! awk -F '\t' '
  function fail(message) {
    print ".chezmoidata/layers.yaml: " message
    failed = 1
  }

  $1 == "force" {
    forces++
    next
  }

  $1 == "layer" {
    layers[$2] = 1
    if ($3 != "true" && $3 != "false")
      fail("layer \"" $2 "\" has non-boolean planned value \"" $3 "\"")
    next
  }

  $1 == "layer-key" {
    if ($3 != "detect" && $3 != "implies" && $3 != "owns" &&
        $3 != "scripts" && $3 != "planned")
      fail("layer \"" $2 "\" has unknown key \"" $3 "\"")
    next
  }

  $1 == "detect-key" {
    if ($3 != "os" && $3 != "osRelease" && $3 != "has" &&
        $3 != "hasAny" && $3 != "fact" && $3 != "requires" &&
        $3 != "conflicts")
      fail("layer \"" $2 "\" has unknown detect key \"" $3 "\"")
    next
  }

  $1 == "fact" {
    if ($3 != "root" && $3 != "libc" && $3 != "desktop" &&
        $3 != "prefixWritable")
      fail("layer \"" $2 "\" uses unsupported fact \"" $3 "\"")
    next
  }

  $1 == "os" {
    if ($3 != "darwin" && $3 != "linux")
      fail("layer \"" $2 "\" uses unsupported os \"" $3 "\"")
    next
  }

  $1 == "reference" {
    references++
    reference_layer[references] = $2
    reference_field[references] = $3
    reference_target[references] = $4
    next
  }

  $1 == "owns" {
    path = $4
    sub(/\/+$/, "", path)
    if (path == "") {
      fail("layer \"" $2 "\" has an empty ownership declaration")
      next
    }
    for (i = 1; i <= ownerships; i++) {
      if (path == owned_path[i] || index(path, owned_path[i] "/") == 1 ||
          index(owned_path[i], path "/") == 1)
        fail("layer \"" $2 "\" ownership \"" path "\" overlaps layer \"" \
             owned_layer[i] "\" ownership \"" owned_path[i] "\"")
    }
    ownerships++
    owned_layer[ownerships] = $2
    owned_path[ownerships] = path
    next
  }

  $1 == "script" {
    if ($4 == "") {
      fail("layer \"" $2 "\" has an empty script declaration")
      next
    }
    if (($4 in script_layer) && script_layer[$4] != $2)
      fail("layers \"" $2 "\" and \"" script_layer[$4] \
           "\" both claim script \"" $4 "\"")
    script_layer[$4] = $2
    next
  }

  {
    fail("unknown lint record \"" $1 "\"")
  }

  END {
    if (forces != 1)
      fail("lint template emitted " forces " force records")
    for (i = 1; i <= references; i++) {
      if (!(reference_target[i] in layers))
        fail("layer \"" reference_layer[i] "\" " reference_field[i] \
             " references unknown layer \"" reference_target[i] "\"")
    }
    exit failed
  }
' "$records" >&2; then
  exit 1
fi

override=$(awk -F '\t' '$1 == "force" { print $2 }' "$records")
mkdir "$work/home"
chezmoi managed -D "$work/home" -S "$repo" --override-data "$override" \
  --exclude=scripts >"$managed_paths"
chezmoi managed -D "$work/home" -S "$repo" --override-data "$override" \
  --include=scripts >"$managed_scripts"
: >"$resolved_owners"

tab=$(printf '\t')
status=0
while IFS="$tab" read -r kind layer planned declaration; do
  [ "$kind" = "owns" ] || continue
  found=0
  while IFS= read -r target; do
    # Ownership declarations use the same glob syntax as .chezmoiignore.
    # shellcheck disable=SC2254
    case "$target" in
    $declaration | $declaration/*)
      found=1
      printf 'path\t%s\t%s\t%s\n' "$target" "$layer" "$declaration" \
        >>"$resolved_owners"
      ;;
    esac
  done <"$managed_paths"
  [ "$found" -eq 0 ] || continue
  if [ "$planned" = "true" ]; then
    printf 'planned: layer "%s" owns missing path "%s"\n' \
      "$layer" "$declaration" >&2
  else
    printf '.chezmoidata/layers.yaml: layer "%s" owns missing path "%s"\n' \
      "$layer" "$declaration" >&2
    status=1
  fi
done <"$records"

while IFS="$tab" read -r kind layer planned declaration; do
  [ "$kind" = "script" ] || continue
  found=0
  while IFS= read -r target; do
    # Script declarations may be globs, such as omarchy-*.sh.
    # shellcheck disable=SC2254
    case "$target" in
    $declaration)
      found=1
      printf 'script\t%s\t%s\t%s\n' "$target" "$layer" "$declaration" \
        >>"$resolved_owners"
      ;;
    esac
  done <"$managed_scripts"
  [ "$found" -eq 0 ] || continue
  if [ "$planned" = "true" ]; then
    printf 'planned: layer "%s" claims missing script "%s"\n' \
      "$layer" "$declaration" >&2
  else
    printf '.chezmoidata/layers.yaml: layer "%s" claims missing script "%s"\n' \
      "$layer" "$declaration" >&2
    status=1
  fi
done <"$records"

if ! awk -F '\t' '
  {
    key = $1 SUBSEP $2
    if ((key in owner) && owner[key] != $3) {
      print ".chezmoidata/layers.yaml: layers \"" owner[key] "\" and \"" \
            $3 "\" both claim " $1 " \"" $2 "\""
      failed = 1
    }
    owner[key] = $3
  }
  END { exit failed }
' "$resolved_owners" >&2; then
  status=1
fi

[ "$status" -eq 0 ] || exit 1
printf 'layer declarations: ok\n'
