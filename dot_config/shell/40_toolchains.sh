# 40_toolchains.sh - non-interactive-safe toolchain availability

export MAMBA_ROOT_PREFIX="${HOME}/.local/opt/micromamba"

if command -v micromamba >/dev/null 2>&1; then
  export MAMBA_EXE="$(command -v micromamba)"
fi
