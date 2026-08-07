# Shell Startup Layout

Shell startup is split into two stages:

- `~/.config/shell/base.sh`: environment and PATH setup needed by every bash/zsh
  shell.
- `~/.config/shell/interactive.sh`: interactive-only setup. It sources
  `base.sh` first, then adds completions, hooks, keychain, and prompt init.

Shell startup files are best understood in terms of two questions:

- Is this a login shell?
- Is this an interactive shell?

`base.sh` handles setup that should exist in any shell session. `interactive.sh`
handles setup that only makes sense when a user is actively at a prompt.

The entrypoint mapping follows each shell's startup rules:

- `~/.profile` -> `base.sh`
- `~/.zprofile` -> `base.sh`
- `~/.zshrc` -> `interactive.sh`
- `~/.bashrc` -> `interactive.sh`
- `~/.bash_profile` -> `interactive.sh` for interactive login shells,
  otherwise `base.sh`

The Bash and Zsh entrypoints differ because the shells read different files:

- Bash interactive login shells read `~/.bash_profile`, but do not automatically
  read `~/.bashrc`.
- Bash interactive non-login shells read `~/.bashrc`.
- Zsh login shells read `~/.zprofile`.
- Zsh interactive shells read `~/.zshrc`.

That means interactive login Bash needs `~/.bash_profile` to choose the full
interactive path, while interactive login Zsh can keep login setup in
`~/.zprofile` and interactive setup in `~/.zshrc`.

The fragment order is explicit inside each loader:

- `base.sh`: `00_init.sh`, `15_host_env.sh`, `25_nvim.sh`, `30_env.sh`,
  `40_python.sh`
- `interactive.sh`: `05_zsh_completions.sh` (zsh) or `10_bash_init.sh` (bash),
  `30_interactive.sh`, `35_keychain.sh`, `45_omarchy.sh` (when
  `SHELL_IS_OMARCHY=1`), the active profile's `90_extras.sh`, `99_finish.sh`

On macOS, interactive zsh keeps prompt setup in `~/.zshrc` so `/etc/zshrc`
finishes its prompt reset before `starship` runs.
