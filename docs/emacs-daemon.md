# Emacs daemon

Every `emacs` command talks to one long-running daemon through `emacsclient`.
With a local display the frame is graphical, so images, inline plots and PDFs
work. Over SSH and on headless hosts the frame opens in the terminal.

The shell's `emacs` function delegates to `~/.local/bin/emacs-session open`.
`emacs-restart` delegates to the same helper's `restart` command. The service
and client logic lives in `dot_local/bin/executable_emacs-session.tmpl`;
`command emacs` still invokes the real editor binary.

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
- The `emacs-session` helper starts the service if no daemon answers. It opens
  a GUI frame with `--no-wait` when
  `WAYLAND_DISPLAY` or `DISPLAY` is set and the session is not SSH, and a
  terminal frame otherwise.
- The daemon outlives the shells that talk to it, so each `emacs` call sets
  the daemon's `SSH_AUTH_SOCK` to the caller's agent. Magit and TRAMP use the
  agent of the most recent client.
- Inside tmux, the helper reads `SSH_CONNECTION` and `SSH_AUTH_SOCK` from
  the tmux session, which tmux updates on every attach, rather than from the
  pane's environment, which keeps the values from when the pane was created.
- `emacs-restart` saves modified buffers without prompting, then restarts the
  service. systemd stops Emacs with SIGTERM, which only auto-saves. If a
  daemon started outside systemd holds the socket, `emacs-restart` stops it
  first.

PGTK Emacs exits when its Wayland connection closes, for example when
Hyprland exits. `Restart=on-failure` in the packaged unit brings it back.

## macOS

launchd owns the daemon through the `local.emacs.daemon` LaunchAgent,
`Library/LaunchAgents/local.emacs.daemon.plist.tmpl` in the source tree.

- The agent starts the daemon through `~/.profile`, for the same reason as the
  Linux drop-in. It runs the executable inside
  `/Applications/Nix Apps/Emacs.app`, never the `emacs` on PATH. That one is
  outside the app bundle, and a daemon started from it aborts on its first GUI
  frame with an `NSImageCacheException` from the zero-size app icon.
- The bundle executable normally restarts itself through `Emacs.sh` and a
  login shell. The agent sets `EMACS_REINVOKED_FROM_SHELL=1` to skip that,
  because `~/.profile` already ran.
- `KeepAlive` restarts the daemon after a crash but not after `kill-emacs`,
  which exits successfully. Output goes to `~/Library/Logs/emacs-daemon.log`.
- `run_onchange_after_load-emacs-agent.sh.tmpl` loads the agent, which starts
  the daemon. It skips loading if the agent is already loaded or another
  daemon holds the socket, and prints what to run instead. A second daemon
  would exit and be restarted every ten seconds.
- The helper also handles macOS. It treats a session as graphical when
  `SSH_CONNECTION` is empty, after the same tmux lookup. macOS has no
  `DISPLAY`, so it passes `--display=Mac -F '((window-system . mac))'`.
  `--display` alone fails on a fresh daemon, because `server.el` recognises
  macport only when the selected frame is already a `mac` frame.
- A new frame opens behind the terminal, so the helper then asks Emacs to
  activate itself with `(do-applescript "tell me to activate")`. That picks
  the app by bundle ID. If a second Emacs is running, it may raise that one
  instead. Do not use System Events from inside the daemon. It can wait on an
  Automation permission prompt, and the daemon stops answering meanwhile.
- If no daemon answers, `emacs` loads the agent, or kickstarts it if it is
  loaded but stopped, then waits up to 30 seconds for the socket. launchctl
  returns before Emacs listens. There is no `--alternate-editor` fallback on
  macOS, because it would start the `emacs` on PATH.
- `emacs-restart` saves modified buffers, unloads the agent and loads it
  again, which rereads the plist. `launchctl bootout` returns before launchd
  has removed the service, and loading in that window fails, so it waits
  until the service is gone.
- The socket is under `$TMPDIR/emacs$UID/`. The agent and Ghostty shells both
  get the per-user Darwin `TMPDIR`. `shell-env.sh` replaces a generic `/tmp`
  value, which would make `emacsclient` look in the wrong place.

Doom's emoji module draws emoji as images unless told otherwise. With no
images downloaded, the first buffer shown in a GUI frame asks to download
them, and the daemon blocks until someone answers in that frame.
`dot_config/doom/config.el` sets `emojify-display-style` to `unicode`.

This was verified on a macOS host on 2026-09-28: GUI frames with images, focus,
restarts, the handover from a daemon started outside launchd, crash recovery,
and terminal frames for a tmux session reattached over SSH. The SSH cases set
`SSH_CONNECTION` by hand, because Remote Login is off on that host. A real SSH
login has not been tried.
