#!/bin/sh

if ! command -v claude &> /dev/null; then
  echo "Installing Claude Code..."
  curl --proto '=https' --tlsv1.2 -fsSL https://claude.ai/install.sh | bash
else
  echo "Claude Code already installed"
fi
