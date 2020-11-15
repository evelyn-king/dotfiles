#!/bin/bash

# install.sh - Setup a development machine
# Cameron King

dotfile_dir=$HOME/dotfiles

# Determine which OS is being used.
case $OSTYPE in
  darwin*)
    echo "This is MacOS"
    ;;
  msys*)
    echo "This is Windows"
    ;;
  linux*)
    echo "This is Linux"
    ;;
  *)
    echo "What the hell is this?"
    ;;
esac

