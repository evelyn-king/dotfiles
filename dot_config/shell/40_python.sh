# 40_python.sh - Python environment helpers
# shellcheck shell=bash

export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-${MAMBA_ROOT_PREFIX_DEFAULT}}"

if command -v micromamba >/dev/null 2>&1; then
  MAMBA_EXE="$(command -v micromamba)"
  export MAMBA_EXE
fi

export JUPYTER_REMOTE_ENV_FILE="${JUPYTER_REMOTE_ENV_FILE:-${XDG_STATE_HOME:-${HOME}/.local/state}/jupyter-remote/current.env}"

if [ "${SHELL_IS_INTERACTIVE:-0}" = "1" ] && [ -n "${SHELL_NAME:-}" ]; then
  if [ -n "${MAMBA_EXE:-}" ]; then
    eval "$("${MAMBA_EXE}" shell hook --shell "${SHELL_NAME}" --root-prefix "${MAMBA_ROOT_PREFIX}")"
  elif [ -f "${LOCAL_PRAXIS_CONDA_BASE}/mambaforge/bin/conda" ]; then
    eval "$("${LOCAL_PRAXIS_CONDA_BASE}/mambaforge/bin/conda" "shell.${SHELL_NAME}" hook)"
    shell_source_if_exists "${LOCAL_PRAXIS_CONDA_BASE}/mambaforge/etc/profile.d/mamba.sh"
  elif [ -f "${LOCAL_PRAXIS_CONDA_BASE}/miniconda3/etc/profile.d/conda.sh" ]; then
    shell_source_if_exists "${LOCAL_PRAXIS_CONDA_BASE}/miniconda3/etc/profile.d/conda.sh"
  fi

  if [ -f "${HOME}/.pixi/bin/pixi" ]; then
    eval "$("${HOME}/.pixi/bin/pixi" completion --shell "${SHELL_NAME}")"
  fi
fi

create_direnv_micromamba() {
  local env_name=${1:-$(basename "$PWD")}
  echo "layout micromamba $env_name" >.envrc
  direnv allow .
}

create_direnv_venv() {
  echo "source .venv/bin/activate" >.envrc
  direnv allow .
}

jupyter_remote_env_file() {
  printf '%s\n' "${JUPYTER_REMOTE_ENV_FILE:-${XDG_STATE_HOME:-${HOME}/.local/state}/jupyter-remote/current.env}"
}

jupyter_remote_load_env() {
  local env_file

  env_file="${1:-$(jupyter_remote_env_file)}"
  if [ ! -f "${env_file}" ]; then
    printf 'Missing Jupyter env file: %s\n' "${env_file}" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "${env_file}"
}
