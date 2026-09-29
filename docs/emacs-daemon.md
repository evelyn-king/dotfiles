# Emacs daemon

Every `emacs` command talks to one long-running daemon through `emacsclient`.
With a local display the frame is graphical, so images, inline plots and PDFs
work. Over SSH and on headless hosts the frame opens in the terminal.

## Linux

systemd owns the daemon through the distribution's `emacs.service`. Omarchy's
Emacs package and Ubuntu's `emacs-common` both install it.

- `dot_config/systemd/user/emacs.service.d/shell-environment.conf` starts the
  daemon through `~/.profile`. Without it, the daemon gets the user manager's
  bare PATH and cannot see mise tools. `~/.profile` can end with a nonzero
  status, so the drop-in joins it to `exec` with `;`, never `&&`.
- `run_onchange_after_enable-emacs-daemon.sh.tmpl` enables the unit. It never
  starts or restarts the daemon, because that would close open frames during
  an apply.
- The `emacs` function in `.chezmoitemplates/shell-interactive.sh` starts the
  service if no daemon answers. It opens a GUI frame with `--no-wait` when
  `WAYLAND_DISPLAY` or `DISPLAY` is set and the session is not SSH, and a
  terminal frame otherwise.
- The daemon outlives the shells that talk to it, so each `emacs` call sets
  the daemon's `SSH_AUTH_SOCK` to the caller's agent. Magit and TRAMP use the
  agent of the most recent client.
- Inside tmux, the function reads `SSH_CONNECTION` and `SSH_AUTH_SOCK` from
  the tmux session, which tmux updates on every attach, rather than from the
  pane's environment, which keeps the values from when the pane was created.
- `emacs-restart` saves modified buffers without prompting, then restarts the
  service. systemd stops Emacs with SIGTERM, which only auto-saves. If a
  daemon started outside systemd holds the socket, `emacs-restart` stops it
  first.

PGTK Emacs exits when its Wayland connection closes, for example when
Hyprland exits. `Restart=on-failure` in the packaged unit brings it back.

## macOS (pending)

macOS still uses the earlier behavior. `emacs` is an alias for a terminal
frame, and `--alternate-editor=""` starts the daemon from whichever shell
calls it first. The Linux changes are all behind
`{{ if eq .chezmoi.os "linux" }}` in `shell-interactive.sh`, and
`.chezmoiignore.tmpl` keeps the systemd files off macOS. Nothing on macOS
changed.

Probes on a macOS host on 2026-09-27, against the Nix `emacs-macport`
30.2.50, found:

- The daemon makes GUI frames with images: `(mac t)`. Closing the last GUI
  frame leaves it running.
- `emacsclient -c` opens a terminal frame, because macOS has no `DISPLAY`.
  `--display=Mac` alone works only once a GUI frame exists. `server.el`
  treats the display as macport only when the selected frame is a `mac`
  frame, and in a fresh daemon the selected frame is the initial terminal.
  Passing the window system as a frame parameter works from a fresh daemon:

  ```sh
  emacsclient -c -n --display=Mac -F '((window-system . mac))'
  ```

- The new frame opens behind the terminal. `select-frame-set-input-focus`
  does not raise it. Adding `-e '(do-applescript "tell me to activate")'`
  brought Emacs to the front when only one Emacs was running. With two
  running, it raised the other one, because it resolves the app by bundle ID.
  Calling System Events from inside the daemon hung it, probably on an
  Automation permission prompt, so do not activate that way.
- `/run/current-system/sw/bin/emacs` is outside the app bundle. A daemon
  started from it aborts on its first GUI frame with an
  `NSImageCacheException` from the zero-size app icon. Start it from
  `/Applications/Nix Apps/Emacs.app/Contents/MacOS/Emacs` instead.
- That executable restarts itself through `Emacs.sh` and a login shell.
  `Emacs.sh` does not quote `$0`, so the space in "Nix Apps" prints a
  harmless `binary operator expected` warning.
- A launchd job that sources `~/.profile` gets the per-user Darwin `TMPDIR`
  and the managed PATH. Its socket is under `$TMPDIR/emacs$UID/`, and
  `emacsclient` finds it with `TMPDIR` inherited or unset. With
  `TMPDIR=/tmp` it fails, which `shell-env.sh` already corrects in new
  shells.

Finish this on a macOS host:

1. Recheck focus with a single daemon and nothing else named Emacs running:
   open a frame with the command above plus the `do-applescript` form, from
   an unlocked Ghostty window, and confirm Emacs comes to the front. If it
   does not, decide whether a frame opening behind the terminal is
   acceptable or keep terminal frames on macOS.
2. Add a LaunchAgent in place of the systemd unit, for example
   `Library/LaunchAgents/<label>.plist` in the source tree, ignored off
   macOS. Run
   `/bin/sh -c '. "$HOME/.profile"; exec "/Applications/Nix Apps/Emacs.app/Contents/MacOS/Emacs" --fg-daemon'`,
   never the `emacs` on PATH. Set `EMACS_REINVOKED_FROM_SHELL=1` in
   `EnvironmentVariables` so the executable skips its second login shell,
   and check that the daemon still has the managed PATH; this is untested.
   Set `RunAtLoad`, and `KeepAlive` to restart on failure only. Load it with
   `launchctl bootstrap gui/$(id -u)` from a `run_onchange_after_` hook, and
   do not kickstart it there.
3. Extend the Linux `emacs` function to macOS rather than copying it. macOS
   has no `DISPLAY`, so treat a session as graphical when `SSH_CONNECTION` is
   empty, and open GUI frames with `--display=Mac -F
   '((window-system . mac))'` and the activation form. Replace the
   `systemctl --user` calls with `launchctl kickstart gui/$(id -u)/<label>`
   for start and `launchctl kickstart -k` for restart. The `SSH_AUTH_SOCK`
   handoff and the tmux lookup apply unchanged.
4. Verify from a local Ghostty shell, from a tmux pane reattached over SSH,
   and from a plain SSH session. Then update this section to describe macOS
   and remove "pending" from its heading.
