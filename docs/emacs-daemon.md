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

Test and finish this on a macOS host:

1. Check that the `emacs-macport` daemon can create GUI frames with images.
   Start a throwaway daemon so the real one is untouched:

   ```sh
   command emacs -Q --fg-daemon=cctest &
   emacsclient -s cctest -c -n
   emacsclient -s cctest -e '(list (window-system) (display-images-p))'
   emacsclient -s cctest -e '(kill-emacs)'
   ```

   Expect `(mac t)`. Also check that the new frame takes focus and comes to
   the front, and that closing the last frame leaves the daemon running. If
   the macport daemon cannot do this reliably, decide whether to keep
   terminal frames on macOS or change the Emacs package in `nix/flake.nix`.
2. Add a LaunchAgent in place of the systemd unit, for example
   `Library/LaunchAgents/<label>.plist` in the source tree, ignored off
   macOS. Run `/bin/sh -c '. "$HOME/.profile"; exec emacs --fg-daemon'` for
   the same reason as the Linux drop-in, with `RunAtLoad` and `KeepAlive`
   set to restart on failure only. Load it with
   `launchctl bootstrap gui/$(id -u)` from a `run_onchange_after_` hook, and
   do not kickstart it there.
3. Confirm that `emacsclient` in a Ghostty shell finds the LaunchAgent's
   socket. `shell-env.sh` points `TMPDIR` at the per-user Darwin temp
   directory for this reason. Compare `(expand-file-name server-name
   server-socket-dir)` in the daemon with where `emacsclient` looks.
4. Extend the Linux `emacs` function to macOS rather than copying it. macOS
   has no `DISPLAY`, so treat a session as graphical when `SSH_CONNECTION` is
   empty. Replace the `systemctl --user` calls with `launchctl kickstart
   gui/$(id -u)/<label>` for start and `launchctl kickstart -k` for restart.
   The `SSH_AUTH_SOCK` handoff and the tmux lookup apply unchanged.
5. Verify from a local Ghostty shell, from a tmux pane reattached over SSH,
   and from a plain SSH session. Then update this section to describe macOS
   and remove "pending" from its heading.
