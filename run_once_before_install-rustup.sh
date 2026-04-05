#!/bin/sh

if ! command -v rustup &> /dev/null; then
  echo "Installing rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y
else
  echo "rustup already installed"
fi
