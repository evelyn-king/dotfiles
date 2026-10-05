#!/usr/bin/env bash
# Sourced by mise through `_.source` in a project's mise.local.toml, which
# create_mise_local_micromamba writes. mise runs it in bash and keeps the
# environment it leaves behind, so this must return rather than exit.

[[ -n "${_MISE_MICROMAMBA_ENV_SOURCING:-}" ]] && return 0
export _MISE_MICROMAMBA_ENV_SOURCING=1

if ! command -v micromamba >/dev/null 2>&1; then
  echo "micromamba is required for this project" >&2
  unset _MISE_MICROMAMBA_ENV_SOURCING
  return 1
fi

eval "$(micromamba shell hook --shell=bash)"
micromamba activate "${MISE_MICROMAMBA_ENV}"

unset _MISE_MICROMAMBA_ENV_SOURCING
