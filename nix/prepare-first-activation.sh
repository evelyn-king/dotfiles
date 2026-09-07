#!/bin/sh
# Preserve only the audited comments-only file written by Determinate's installer.
set -eu

conf=/etc/nix/nix.custom.conf
backup=$conf.before-nix-darwin

# nix-darwin owns the symlink after activation. Nothing to migrate if absent.
if [ -L "$conf" ] || [ ! -e "$conf" ]; then
  exit 0
fi

if [ ! -f "$conf" ]; then
  printf 'Refusing to move non-regular file: %s\n' "$conf" >&2
  exit 1
fi

checksum=$(/usr/bin/shasum -a 256 "$conf")
if [ "${checksum%% *}" != 3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa ]; then
  printf 'Preserving unrecognized content in %s; review it before activation.\n' "$conf" >&2
  exit 1
fi

if [ -e "$backup" ] || [ -L "$backup" ]; then
  printf 'Preserving existing backup: %s\n' "$backup" >&2
  exit 1
fi

/bin/mv -n "$conf" "$backup"
test ! -e "$conf"
printf 'Preserved installer configuration as %s\n' "$backup"
