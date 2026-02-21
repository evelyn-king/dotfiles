#!/bin/bash

# Use sccache with fallback to rustc
if command -v sccache &>/dev/null; then
  exec sccache "$@"
else
  exec rustc "$@"
fi
