#!/usr/bin/env sh
# Use sccache if available, otherwise rustc
if command -v sccache >/dev/null 2>&1; then
  exec sccache "$@"
else
  exec rustc "$@"
fi
