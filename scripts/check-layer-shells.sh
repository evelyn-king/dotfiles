#!/bin/sh

# Render shell files for one host-native scenario, then check each dialect with
# its own interpreter.

set -eu

repo=$(
  unset CDPATH
  cd "$(dirname "$0")/.."
  pwd
)
cd "$repo"

. scripts/layer-scenarios.sh

scenario=${1:-macbook}
scenario_record=$(layer_scenario "$scenario") || {
  printf 'unknown scenario: %s\n' "$scenario" >&2
  exit 2
}
IFS='|' read -r _ os os_id os_id_like root libc desktop present <<EOF
$scenario_record
EOF

require() {
  command -v "$1" || {
    printf 'layer shells: %s is required\n' "$1" >&2
    exit 1
  }
}

chezmoi_bin=$(require chezmoi)
dash_bin=$(require dash)
shellcheck_bin=$(require shellcheck)
bash_bin=$(require bash)
zsh_bin=$(require zsh)

work=$(mktemp -d "${TMPDIR:-/tmp}/layer-shells.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
home="$work/home"
cache="$work/cache"
config="$work/chezmoi.toml"
state="$work/state.boltdb"
probe_path="$work/path"
rendered="$work/rendered"
mkdir -p "$home/.local/bin" "$cache" "$probe_path" "$rendered" "$work/tmp"

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
  printf 'layer shells (%s): %s\n' "$scenario" "$1" >&2
  exit 1
}

context=$(sandbox_chezmoi execute-template '{{ .chezmoi.os }}|{{ if hasKey .chezmoi.osRelease "id" }}{{ .chezmoi.osRelease.id }}{{ end }}|{{ if hasKey .chezmoi.osRelease "idLike" }}{{ .chezmoi.osRelease.idLike }}{{ end }}')
[ "$context" = "$os|$os_id|$os_id_like" ] ||
  fail "scenario requires $os|$os_id|$os_id_like, host reports $context"

render() {
  sandbox_chezmoi execute-template --file "$repo/$1" >"$2"
}

render .chezmoitemplates/shell-env.sh "$rendered/shell-env.sh"
render .chezmoitemplates/shell-path.sh "$rendered/shell-path.sh"
render .chezmoitemplates/shell-interactive.sh "$rendered/shell-interactive.sh"
render run_onchange_after_fetch-portable-tools.sh.tmpl "$rendered/fetch-portable-tools.sh"
render dot_bashrc.tmpl "$home/.bashrc"
render dot_zshenv.tmpl "$home/.zshenv"
render dot_zshrc.tmpl "$home/.zshrc"

for source in \
  bootstrap-standalone.sh \
  "$rendered/fetch-portable-tools.sh" \
  "$rendered/shell-env.sh" \
  "$rendered/shell-path.sh" \
  "$rendered/shell-interactive.sh"; do
  "$dash_bin" -n "$source"
  "$shellcheck_bin" -s sh "$source"
done

"$bash_bin" -n dot_bash_profile
"$bash_bin" -n "$home/.bashrc"
"$zsh_bin" -n "$home/.zshenv"
"$zsh_bin" -n "$home/.zshrc"

# The shared PATH adds the Nix system profile on this host. Put harmless stubs
# ahead of it so startup checks do not launch agents or read tool state.
stub="$home/.local/bin/shell-check-stub"
printf '#!/bin/sh\nexit 0\n' >"$stub"
chmod 0755 "$stub"
for command in keychain direnv pixi mise fzf starship zoxide atuin; do
  ln -s shell-check-stub "$home/.local/bin/$command"
done

case "$os" in
darwin) docker_platform=linux/amd64 ;;
linux) docker_platform= ;;
*) fail "unsupported scenario OS $os" ;;
esac

# The child shells expand these values after reading their startup files.
# shellcheck disable=SC2016
startup_assertions='[ "$XDG_CONFIG_HOME" = "$HOME/.config" ]
[ "${DOCKER_DEFAULT_PLATFORM:-}" = "$EXPECTED_DOCKER_PLATFORM" ]
case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) exit 1 ;;
esac'
# shellcheck disable=SC2016
bash_startup_assertions="$startup_assertions
"'[ "$BASH_COMPLETION_USER_DIR" = "$XDG_DATA_HOME/bash-completion" ]'

if ! HOME="$home" \
  PATH="$probe_path" \
  TMPDIR="$work/tmp" \
  LANG=C \
  SSH_CONNECTION='' \
  SSH_AUTH_SOCK='' \
  BASH_ENV='' \
  EXPECTED_DOCKER_PLATFORM="$docker_platform" \
  "$bash_bin" --noprofile --rcfile "$home/.bashrc" -e -i -c \
    "$bash_startup_assertions" </dev/null >"$work/bash.out" 2>"$work/bash.err"; then
  sed -n '1,$p' "$work/bash.err" >&2
  fail "interactive bash startup failed"
fi

if ! HOME="$home" \
  ZDOTDIR="$home" \
  PATH="$probe_path" \
  TMPDIR="$work/tmp" \
  LANG=C \
  SSH_CONNECTION='' \
  SSH_AUTH_SOCK='' \
  EXPECTED_DOCKER_PLATFORM="$docker_platform" \
  "$zsh_bin" -d -e -i -c "$startup_assertions" \
    </dev/null >"$work/zsh.out" 2>"$work/zsh.err"; then
  sed -n '1,$p' "$work/zsh.err" >&2
  fail "interactive zsh startup failed"
fi

printf 'layer shells (%s): ok\n' "$scenario"
