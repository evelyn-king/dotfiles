#!/bin/sh

# Run native Linux sandbox applies. Native runs are offline; image builds and
# explicit slow bootstrap cases use the network.

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
bootstrap_ubuntu_image=dotfiles-layer-bootstrap-ubuntu:24.04-amd64
bootstrap_alpine_amd64_image=dotfiles-layer-bootstrap-alpine:3.22-amd64
bootstrap_alpine_arm64_image=dotfiles-layer-bootstrap-alpine:3.22-arm64
dockerfile=scripts/layer-test.Dockerfile
build=0
slow=0
slow_case=all
fixture_root=""
git_daemon_pid=""
git_daemon_port=${LAYER_GIT_PORT:-19418}

cleanup() {
  if [ -n "$git_daemon_pid" ]; then
    kill "$git_daemon_pid" 2>/dev/null || true
    wait "$git_daemon_pid" 2>/dev/null || true
  fi
  [ -z "$fixture_root" ] || rm -rf "$fixture_root"
}
trap cleanup EXIT HUP INT TERM

usage() {
  printf 'usage: %s [--build] [--slow] [--slow-case=NAME]\n' "$0" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --build) build=1 ;;
  --slow) slow=1 ;;
  --slow-case=*)
    slow=1
    slow_case=${1#--slow-case=}
    case "$slow_case" in
    ubuntu-amd64 | alpine-amd64 | alpine-arm64 | clone) ;;
    *)
      usage
      exit 2
      ;;
    esac
    ;;
  *)
    usage
    exit 2
    ;;
  esac
  shift
done

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

  if [ "$slow" -eq 1 ]; then
    case "$slow_case" in
    all | ubuntu-amd64)
      "$docker_bin" build \
        --file "$dockerfile" \
        --platform linux/amd64 \
        --target ubuntu-bootstrap \
        --tag "$bootstrap_ubuntu_image" \
        scripts
      ;;
    esac
    case "$slow_case" in
    all | alpine-amd64)
      "$docker_bin" build \
        --file "$dockerfile" \
        --platform linux/amd64 \
        --target alpine-bootstrap \
        --tag "$bootstrap_alpine_amd64_image" \
        scripts
      ;;
    esac
    case "$slow_case" in
    all | alpine-arm64)
      "$docker_bin" build \
        --file "$dockerfile" \
        --platform linux/arm64 \
        --target alpine-bootstrap \
        --tag "$bootstrap_alpine_arm64_image" \
        scripts
      ;;
    esac
  fi
fi

for image in "$ubuntu_image" "$alpine_image"; do
  if ! "$docker_bin" image inspect "$image" >/dev/null 2>&1; then
    printf 'layer containers: missing image %s; run %s --build\n' \
      "$image" "$0" >&2
    exit 1
  fi
done

if [ "$slow" -eq 1 ]; then
  case "$slow_case" in
  all)
    bootstrap_images="$bootstrap_ubuntu_image
$bootstrap_alpine_amd64_image
$bootstrap_alpine_arm64_image"
    ;;
  ubuntu-amd64) bootstrap_images=$bootstrap_ubuntu_image ;;
  alpine-amd64) bootstrap_images=$bootstrap_alpine_amd64_image ;;
  alpine-arm64) bootstrap_images=$bootstrap_alpine_arm64_image ;;
  clone) bootstrap_images= ;;
  esac
  for image in $bootstrap_images; do
    if ! "$docker_bin" image inspect "$image" >/dev/null 2>&1; then
      printf 'layer containers: missing image %s; run %s --build --slow\n' \
        "$image" "$0" >&2
      exit 1
    fi
  done
fi

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

prepare_fixture() {
  command -v git >/dev/null 2>&1 || {
    printf 'layer containers: git is required to prepare the slow fixture\n' >&2
    exit 1
  }
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/layer-bootstrap.XXXXXX")
  fixture_repo="$fixture_root/repo"
  mkdir "$fixture_repo"
  cp -R "$repo/." "$fixture_repo"

  # External downloads have their own network check. The bootstrap cases keep
  # the full mise install but omit the Vim tarballs.
  : >"$fixture_repo/dot_vim/pack/plugins/start/.chezmoiexternal.toml.tmpl"
  git -C "$fixture_repo" add -A
  if ! git -C "$fixture_repo" diff --cached --quiet; then
    git -C "$fixture_repo" \
      -c user.name='Layer test' \
      -c user.email='layer-test@invalid' \
      -c commit.gpgsign=false \
      commit --quiet --no-verify -m 'Create layer test fixture'
  fi
  git -C "$fixture_repo" update-ref refs/heads/layer-test HEAD
  fixture_commit=$(git -C "$fixture_repo" rev-parse HEAD)

  git daemon \
    --reuseaddr \
    --export-all \
    --base-path="$fixture_root" \
    --listen=0.0.0.0 \
    --port="$git_daemon_port" &
  git_daemon_pid=$!
  ready=0
  attempt=0
  while [ "$attempt" -lt 10 ]; do
    if git ls-remote \
      "git://127.0.0.1:$git_daemon_port/repo" >/dev/null 2>&1; then
      ready=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  [ "$ready" -eq 1 ] || {
    printf 'layer containers: fixture git server did not start\n' >&2
    exit 1
  }
  printf 'bootstrap fixture: commit=%s\n' "$fixture_commit"
}

run_bootstrap() {
  scenario=$1
  image=$2
  bootstrap_platform=$3
  bootstrap_machine=$4
  expected_layers=$(
    awk -v want="$scenario" \
      '$1 == want { $1 = ""; sub(/^ +/, ""); print }' \
      scripts/layer-matrix.golden
  )
  [ -n "$expected_layers" ] || {
    printf 'layer containers: missing matrix row for %s\n' "$scenario" >&2
    exit 1
  }

  printf 'bootstrap expected: scenario=%s uid=65532 arch=%s layers=%s\n' \
    "$scenario" "$bootstrap_machine" "$expected_layers"

  # The container shell expands the command string after Docker injects the
  # expected values.
  # shellcheck disable=SC2016
  "$docker_bin" run \
    --rm \
    --platform "$bootstrap_platform" \
    --read-only \
    --tmpfs /tmp:rw,exec,nosuid,mode=1777,size=256m \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --user 65532:65532 \
    --workdir /home/test \
    --mount type=volume,dst=/home/test \
    --mount "type=bind,src=$repo,dst=/repo,readonly" \
    --env HOME=/home/test \
    --env USER=test \
    --env BOOTSTRAP_REPO_URL="git://host.docker.internal:$git_daemon_port/repo" \
    --env BOOTSTRAP_REPO_REF=layer-test \
    --env EXPECTED_COMMIT="$fixture_commit" \
    --env EXPECTED_LAYERS="$expected_layers" \
    --env EXPECTED_MACHINE="$bootstrap_machine" \
    "$image" \
    /bin/sh -eu -c '
      [ "$(id -u)" = 65532 ]
      [ "$(uname -m)" = "$EXPECTED_MACHINE" ]
      ! command -v git >/dev/null 2>&1
      ! command -v chezmoi >/dev/null 2>&1

      /bin/sh /repo/bootstrap-standalone.sh

      PATH="$HOME/.local/bin:$PATH"
      export PATH
      chezmoi --version
      mise --version
      [ -x "$HOME/.local/bin/mise" ]
      [ -f "$HOME/.config/mise/conf.d/20-standalone.toml" ]
      [ ! -e "$HOME/.config/mise/conf.d/10-dotfiles.toml" ]

      source_dir="$HOME/.local/share/chezmoi"
      head=$(sed -n "1p" "$source_dir/.git/HEAD")
      case "$head" in
      "ref: "*)
        ref=${head#ref: }
        if [ -f "$source_dir/.git/$ref" ]; then
          actual_commit=$(sed -n "1p" "$source_dir/.git/$ref")
        else
          actual_commit=$(grep " $ref$" "$source_dir/.git/packed-refs" | \
            sed -n "s/ .*//p")
        fi
        ;;
      *) actual_commit=$head ;;
      esac
      [ "$actual_commit" = "$EXPECTED_COMMIT" ]

      actual_layers=$(chezmoi execute-template \
        "{{ includeTemplate \"layers.yaml.tmpl\" . }}" | \
        sed -n "s/^names: //p")
      [ "$actual_layers" = "$EXPECTED_LAYERS" ]

      /bin/sh -eu -c '\''
        PATH="$HOME/.local/bin:$PATH"
        export PATH
        chezmoi apply --refresh-externals=never
      '\''
      printf "bootstrap actual: arch=%s layers=%s\n" \
        "$(uname -m)" "$actual_layers"
    '
}

run_production_clone_smoke() {
  printf 'production clone smoke: branch=main\n'
  # No git binary is present. This checks the real HTTPS URL separately from
  # the worktree fixture used by the end-to-end cases.
  # shellcheck disable=SC2016
  "$docker_bin" run \
    --rm \
    --platform "$platform" \
    --read-only \
    --tmpfs /tmp:rw,exec,nosuid,mode=1777,size=128m \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --user 65532:65532 \
    --workdir /home/test \
    --tmpfs /home/test:rw,exec,nosuid,uid=65532,gid=65532,mode=0700,size=64m \
    --env HOME=/home/test \
    --env USER=test \
    --env CHEZMOI_PROFILE=personal \
    "$alpine_image" \
    /bin/sh -eu -c '
      ! command -v git >/dev/null 2>&1
      chezmoi init --use-builtin-git=true --promptDefaults --branch main \
        https://github.com/evelyn-king/dotfiles.git
      [ -f "$HOME/.local/share/chezmoi/README.md" ]
    '
  printf 'production clone smoke: ok\n'
}

if [ "$slow" -eq 1 ]; then
  case "$slow_case" in
  all | ubuntu-amd64 | alpine-amd64 | alpine-arm64) prepare_fixture ;;
  esac
  case "$slow_case" in
  all | ubuntu-amd64)
    run_bootstrap \
      ubuntu-noroot "$bootstrap_ubuntu_image" linux/amd64 x86_64
    ;;
  esac
  case "$slow_case" in
  all | alpine-amd64)
    run_bootstrap \
      alpine-noroot "$bootstrap_alpine_amd64_image" linux/amd64 x86_64
    ;;
  esac
  case "$slow_case" in
  all | alpine-arm64)
    run_bootstrap \
      alpine-noroot "$bootstrap_alpine_arm64_image" linux/arm64 aarch64
    ;;
  esac
  case "$slow_case" in
  all | clone) run_production_clone_smoke ;;
  esac
  printf 'layer bootstrap containers: ok\n'
fi

printf 'layer containers: ok\n'
