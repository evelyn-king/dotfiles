# Ubuntu package ownership

This repo supports Ubuntu 26.04 on x86_64 headless development hosts.
[`20-ubuntu.toml`](../../dot_config/mise/conf.d/20-ubuntu.toml) declares native
packages under `[bootstrap.packages]`. The shared `[tools]` declarations in
the same directory own versioned development tools. Read the declarations
for package names and tool versions.

`run_before_05-bootstrap-ubuntu.sh.tmpl` checks the Ubuntu release and CPU
architecture, then invokes mise's system-file and APT package phases before
chezmoi writes home configuration files. Package installation requires sudo or
root. Repeated applies restore missing packages without removing unlisted
packages. APT's `latest` declarations accept already-installed versions, so
ordinary Ubuntu updates remain responsible for native package upgrades.

The Ubuntu bootstrap also manages
`/etc/apt/apt.conf.d/99-dotfiles-no-recommends`. It disables APT's recommended
dependencies globally on this headless host and takes effect before package
installation. Required dependencies still install. To request recommendations
for an individual manual installation, pass `--install-recommends` to APT.
Removing the declaration alone does not remove the policy file.

The mise tool hook runs separately against the committed source-tree lock.
Ubuntu shares the existing `linux-x64` artifacts with Omarchy. The lock remains
in the source tree and is never applied to the home directory.

Keep native build dependencies and terminal applications in the Ubuntu package
declarations. A tool moved to mise must lose its explicit declaration from the
native package lists. Native Python is an OS dependency; the development
interpreter comes from mise. Do not replace Ubuntu's `/usr/bin/python3`.

Ubuntu's managed configuration is headless. Chezmoi excludes the desktop
configuration and the Omarchy-specific agent skill. Doom uses terminal Emacs
with vterm and omits its graphical PDF module. Fonts and clipboard behavior
over SSH belong to the local terminal. The remote host supplies the standard
terminal descriptions, including `xterm-256color` and `tmux-256color`. The local
Ghostty configuration enables `ssh-env`, which uses the xterm fallback for SSH.
For SSH clients that bypass Ghostty's integration, use a supported `TERM` or
follow [Ghostty's terminfo instructions](https://ghostty.org/docs/help/terminfo).

Chezmoi owns shell startup and application configuration. Do not enable mise's
dotfile or shell-activation writing phases for these files. User accounts,
SSH server configuration, firewall rules, service enrollment, and signing keys
remain host administration tasks.

Follow [cold-start deployment](../cold-start.md#ubuntu-2604-x86_64-headless)
for initial installation and verification. Chezmoi installs the pinned mise
release; see [mise ownership](mise.md#installation-and-updates) for updates.
Preview native file and package changes with:

```bash
MISE_CONFIG_DIR="$(chezmoi source-path)/dot_config/mise" \
  MISE_SYSTEM_PACKAGES_MANAGERS=apt \
  mise --cd / bootstrap --only files,packages --dry-run
```

Use Ubuntu's normal update process for the system and `mup` for the shared
floating tool versions. See [mise ownership](mise.md) before moving tools
between package managers or removing old installations.
