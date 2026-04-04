#!/usr/bin/env sh
# Use sccache if available, otherwise rustc
if command -v &> /dev/null; then
  exec sccache "@"
else
  exec "@"
fi
