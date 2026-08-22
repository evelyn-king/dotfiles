#!/bin/sh

# Apply one host-native layer scenario in a fully isolated chezmoi sandbox.

set -eu

repo=$(
  unset CDPATH
  cd "$(dirname "$0")/.."
  pwd
)
cd "$repo"

. scripts/layer-scenarios.sh

scenario=${1:-macbook}
chezmoi_bin=$(command -v chezmoi) || {
  printf 'chezmoi is required\n' >&2
  exit 1
}

scenario_record=$(layer_scenario "$scenario") || {
  printf 'unknown scenario: %s\n' "$scenario" >&2
  exit 2
}
IFS='|' read -r _ os os_id os_id_like root libc desktop present <<EOF
$scenario_record
EOF

work=$(mktemp -d "${TMPDIR:-/tmp}/layer-apply.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
home="$work/home"
cache="$work/cache"
config="$work/chezmoi.toml"
state="$work/state.boltdb"
probe_path="$work/path"
records="$work/records"
managed_paths="$work/managed-paths"
managed_scripts="$work/managed-scripts"
status_output="$work/status"
portable_script="$work/fetch-portable-tools.sh"
mkdir -p "$home" "$cache" "$probe_path"

layer_scenario_config "$repo" "$root" "$libc" "$desktop" "$present" >"$config"

sandbox_chezmoi() {
  HOME="$home" PATH="$probe_path" "$chezmoi_bin" \
    -D "$home" \
    -c "$config" \
    -S "$repo" \
    --cache "$cache" \
    --persistent-state "$state" \
    --color=false \
    --no-tty \
    "$@"
}

fail() {
  printf 'layer apply (%s): %s\n' "$scenario" "$1" >&2
  exit 1
}

context=$(sandbox_chezmoi execute-template '{{ .chezmoi.os }}|{{ if hasKey .chezmoi.osRelease "id" }}{{ .chezmoi.osRelease.id }}{{ end }}|{{ if hasKey .chezmoi.osRelease "idLike" }}{{ .chezmoi.osRelease.idLike }}{{ end }}')
[ "$context" = "$os|$os_id|$os_id_like" ] ||
  fail "scenario requires $os|$os_id|$os_id_like, host reports $context"

expected_layers=$(awk -v want="$scenario" '$1 == want { $1 = ""; sub(/^ +/, ""); print }' scripts/layer-matrix.golden)
[ -n "$expected_layers" ] || fail "missing expected matrix row"
actual_layers=$(
  sandbox_chezmoi execute-template \
    '{{ includeTemplate "layers.yaml.tmpl" . }}' |
    sed -n 's/^names: //p'
)
[ "$actual_layers" = "$expected_layers" ] ||
  fail "resolved $actual_layers, expected $expected_layers"
active_words=$(printf '%s\n' "$actual_layers" | sed 's/^\[//; s/\]$//; s/,//g')

is_active() {
  case " $active_words " in
  *" $1 "*) return 0 ;;
  *) return 1 ;;
  esac
}

sandbox_chezmoi execute-template \
  '{{ includeTemplate "layer-lint-records.tmpl" . }}' >"$records"

sandbox_chezmoi apply \
  --exclude=scripts,externals \
  --force \
  --refresh-externals=never

sandbox_chezmoi managed \
  --exclude=scripts \
  --path-style=relative >"$managed_paths"
sandbox_chezmoi managed \
  --include=scripts \
  --path-style=relative >"$managed_scripts"

path_is_managed() {
  declaration=$1
  while IFS= read -r target; do
    # Layer ownership uses the same glob syntax as .chezmoiignore.
    # shellcheck disable=SC2254
    case "$target" in
    $declaration | $declaration/*) return 0 ;;
    esac
  done <"$managed_paths"
  return 1
}

script_is_managed() {
  declaration=$1
  while IFS= read -r target; do
    # Script declarations may contain globs.
    # shellcheck disable=SC2254
    case "$target" in
    $declaration) return 0 ;;
    esac
  done <"$managed_scripts"
  return 1
}

tab=$(printf '\t')
while IFS="$tab" read -r kind layer planned declaration; do
  [ "$planned" = "false" ] || continue
  case "$kind" in
  owns)
    if is_active "$layer"; then
      path_is_managed "$declaration" ||
        fail "active layer $layer does not manage $declaration"
    elif path_is_managed "$declaration"; then
      fail "inactive layer $layer manages $declaration"
    fi
    ;;
  script)
    if is_active "$layer"; then
      script_is_managed "$declaration" ||
        fail "active layer $layer does not manage script $declaration"
    elif script_is_managed "$declaration"; then
      fail "inactive layer $layer manages script $declaration"
    fi
    ;;
  esac
done <"$records"

sandbox_chezmoi execute-template \
  --file "$repo/run_onchange_after_fetch-portable-tools.sh.tmpl" >"$portable_script"
grep -F 'VERSION="v2026.8.9"' "$portable_script" >/dev/null ||
  fail "portable mise version did not render"

case "$os" in
darwin)
  rust_platform=apple-darwin
  credential_helper='helper = osxkeychain'
  ;;
linux)
  rust_platform=unknown-linux-gnu
  credential_helper='helper = libsecret'
  ;;
*) fail "unsupported scenario OS $os" ;;
esac
if is_active rust; then
  arch=$(sandbox_chezmoi execute-template '{{ .chezmoi.arch }}')
  case "$arch" in
  arm64) rust_cpu=aarch64 ;;
  amd64) rust_cpu=x86_64 ;;
  *) fail "unsupported rust architecture $arch" ;;
  esac
  grep -F "default_toolchain = \"stable-$rust_cpu-$rust_platform\"" \
    "$home/.rustup/settings.toml" >/dev/null ||
    fail "rustup did not render the $os toolchain"
fi
grep -F "$credential_helper" "$home/.config/git/config" >/dev/null ||
  fail "git did not render the $os credential helper"

sandbox_chezmoi status \
  --exclude=scripts,externals \
  --refresh-externals=never >"$status_output"
if [ -s "$status_output" ]; then
  sed -n '1,$p' "$status_output" >&2
  fail "sandbox is not clean after apply"
fi

printf 'layer apply (%s): ok\n' "$scenario"
