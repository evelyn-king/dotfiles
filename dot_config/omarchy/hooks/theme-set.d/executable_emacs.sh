#!/bin/bash
# Retint the Emacs daemon after `omarchy theme set` ($1 is the theme slug).
# doom-omarchy reads the new palette itself; this only asks it to reload. A
# daemon that is not running starts on the current theme anyway.

command -v emacsclient >/dev/null || exit 0
timeout 10 emacsclient --eval "(+omarchy-reload-theme-h)" >/dev/null 2>&1 || true
