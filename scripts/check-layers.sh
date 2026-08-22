#!/bin/sh

# Run the fast, offline layer checks.

set -eu

repo=$(
  unset CDPATH
  cd "$(dirname "$0")/.."
  pwd
)
cd "$repo"

scenario=${1:-macbook}

./scripts/layer-matrix.sh
./scripts/lint-layers.sh
./scripts/check-layer-applies.sh "$scenario"
./scripts/check-layer-shells.sh "$scenario"

printf 'layer checks: ok\n'
