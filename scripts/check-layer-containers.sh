#!/bin/sh

# Run native Linux sandbox applies. Image builds use the network; test runs do
# not.

set -eu

repo=$(
  unset CDPATH
  cd "$(dirname "$0")/.."
  pwd
)
cd "$repo"

. scripts/layer-scenarios.sh

docker_bin=$(command -v docker) || {
  printf 'layer containers: docker is required\n' >&2
  exit 1
}

ubuntu_image=dotfiles-layer-ubuntu:2.70.5
alpine_image=dotfiles-layer-alpine:2.70.5
dockerfile=scripts/layer-test.Dockerfile
build=0

usage() {
  printf 'usage: %s [--build]\n' "$0" >&2
}

case "$#" in
0) ;;
1)
  [ "$1" = "--build" ] || {
    usage
    exit 2
  }
  build=1
  ;;
*)
  usage
  exit 2
  ;;
esac

if ! "$docker_bin" info >/dev/null 2>&1; then
  printf 'layer containers: docker daemon is not running\n' >&2
  exit 1
fi

daemon_arch=$("$docker_bin" info --format '{{.Architecture}}')
case "$daemon_arch" in
aarch64 | arm64)
  platform=linux/arm64
  machine=aarch64
  ;;
x86_64 | amd64)
  platform=linux/amd64
  machine=x86_64
  ;;
*)
  printf 'layer containers: unsupported daemon architecture %s\n' \
    "$daemon_arch" >&2
  exit 1
  ;;
esac

if [ "$build" -eq 1 ]; then
  "$docker_bin" build \
    --file "$dockerfile" \
    --platform "$platform" \
    --target ubuntu \
    --tag "$ubuntu_image" \
    scripts
  "$docker_bin" build \
    --file "$dockerfile" \
    --platform "$platform" \
    --target alpine \
    --tag "$alpine_image" \
    scripts
fi

for image in "$ubuntu_image" "$alpine_image"; do
  if ! "$docker_bin" image inspect "$image" >/dev/null 2>&1; then
    printf 'layer containers: missing image %s; run %s --build\n' \
      "$image" "$0" >&2
    exit 1
  fi
done

print_probes() {
  scenario_present=$1
  printf 'container probes:'
  for binary in $LAYER_PROBE_BINARIES; do
    value=false
    case " $scenario_present " in
    *" $binary "*) value=true ;;
    esac
    printf ' %s=%s' "$binary" "$value"
  done
  printf '\n'
}

run_scenario() {
  scenario=$1
  image=$2
  scenario_record=$(layer_scenario "$scenario") || {
    printf 'layer containers: unknown scenario %s\n' "$scenario" >&2
    exit 2
  }
  IFS='|' read -r _ os os_id os_id_like root _ _ present <<EOF
$scenario_record
EOF

  [ "$os" = linux ] || {
    printf 'layer containers: scenario %s is not Linux\n' "$scenario" >&2
    exit 1
  }
  if [ "$root" = true ]; then
    uid=0
  else
    uid=65532
  fi

  printf 'container expected: scenario=%s uid=%s arch=%s os=%s id=%s idLike=%s\n' \
    "$scenario" "$uid" "$machine" "$os" "$os_id" "$os_id_like"
  print_probes "$present"

  # The container shell expands the command string after Docker injects the
  # expected values.
  # shellcheck disable=SC2016
  "$docker_bin" run \
    --rm \
    --platform "$platform" \
    --network=none \
    --read-only \
    --tmpfs /tmp:rw,exec,nosuid,mode=1777,size=128m \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --user "$uid:$uid" \
    --workdir /repo \
    --mount "type=bind,src=$repo,dst=/repo,readonly" \
    --env EXPECTED_UID="$uid" \
    --env EXPECTED_MACHINE="$machine" \
    --env EXPECTED_OS_ID="$os_id" \
    --env EXPECTED_OS_ID_LIKE="$os_id_like" \
    "$image" \
    /bin/sh -eu -c '
      actual_uid=$(id -u)
      actual_machine=$(uname -m)
      . /etc/os-release
      actual_id_like=${ID_LIKE:-}
      printf "container actual: uid=%s arch=%s os=linux id=%s idLike=%s\n" \
        "$actual_uid" "$actual_machine" "$ID" "$actual_id_like"
      [ "$actual_uid" = "$EXPECTED_UID" ]
      [ "$actual_machine" = "$EXPECTED_MACHINE" ]
      [ "$ID" = "$EXPECTED_OS_ID" ]
      [ "$actual_id_like" = "$EXPECTED_OS_ID_LIKE" ]
      exec ./scripts/check-layer-applies.sh "$1"
    ' sh "$scenario"
}

for scenario in \
  ubuntu-noroot \
  ubuntu-noroot-tooled \
  ubuntu-root \
  ubuntu-desktop; do
  run_scenario "$scenario" "$ubuntu_image"
done
run_scenario alpine-noroot "$alpine_image"

printf 'layer containers: ok\n'
