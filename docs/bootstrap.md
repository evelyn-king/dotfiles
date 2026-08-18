# Bootstrapping a fresh machine

Supported: macOS, Ubuntu/Debian, Arch, and Ubuntu under WSL.

```bash
curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/machinetype/portable/bootstrap.sh | bash
```

That covers layers 0-2 below. Layer 3 is yours, and is the checklist at the end.

## The layers

Each layer is owned by exactly one thing. Knowing which one owns a given tool
is how you know where to change it.

| Layer | What | Owner |
|---|---|---|
| 0 | git and chezmoi | `bootstrap.sh` |
| 1 | dotfiles and chezmoi externals | `chezmoi apply` |
| 2 | language runtimes and global CLI tools | mise, via a `chezmoi apply` hook |
| 3 | everything else — system packages, editors, fonts, keys | you |

The load-bearing rule on this branch: **nothing here installs the tools the
configs configure.** Every config detects what it finds at runtime, so a
missing tool costs you that tool and nothing else — not a broken shell. Install
whatever you want by whatever means the machine prefers; brew, apt, pacman and
nix all work, and the dotfiles do not care which you picked.

## What `bootstrap.sh` does

It is idempotent; re-running it is safe and skips whatever is already done.

1. Identifies the platform from `uname -s` and `/etc/os-release`, and stops
   rather than guessing if it is not one of the supported ones. WSL is detected
   separately from `/proc/sys/kernel/osrelease`, since it reports `ID=ubuntu`
   and is the same platform for packaging but not for credentials.
2. Installs **git**, if missing — Command Line Tools on macOS, `apt-get` on
   Ubuntu, `pacman` on Arch. This is the only step that needs sudo, and only on
   Linux.
3. Installs **chezmoi**, if missing, into `~/.local/bin` using the upstream
   standalone installer. That installer behaves identically on all three
   platforms and needs no package manager, which keeps this step from having to
   know what each distro calls the package.
4. Runs `chezmoi init --apply --branch machinetype/portable` against the repo
   **over HTTPS**, because `origin` is an SSH remote and a fresh machine has no
   key yet. Override the branch with `DOTFILES_BRANCH=...`.
5. Creates `~/.config/shell/extras.sh` mode `600` if it is missing.
6. Warns if mise is absent, since that means layer 2 did nothing.

Those two programs are exactly the ones chezmoi cannot bootstrap for itself.
Everything past them is a deliberate omission, not a gap.

## Layer 2: mise

`chezmoi apply` runs `run_onchange_after_mise-install.sh.tmpl`, which is keyed
on the hash of `dot_config/mise/config.toml`. Adding a tool is a one-line edit
plus `chezmoi apply` — there is no separate command to remember.

```bash
mise install          # what the hook runs
mise ls               # what you have
mise upgrade --bump   # bump every pin, review the diff, commit
```

The pins are exact on purpose. `mise upgrade --bump` rewrites `config.toml` in
place, so an upgrade arrives as one reviewable diff rather than as silent drift
between machines.

If mise is not installed, the hook exits quietly and you get no runtimes. That
is the intended behaviour — install mise, then run `chezmoi apply` again.

`bun` and `uv` are deliberately not declared in mise: they are the backends
mise shells out to for its `npm:` and `pipx:` tools, so installing them
*through* mise would be a needless ordering dependency. Install them yourself
if you want the faster backends; without them mise falls back to slower
defaults rather than failing.

## Layer 3: the manual checklist

- [ ] **The tools themselves.** Terminal, editors, `git`, `fzf`, `eza`, `bat`,
      `ripgrep`, `direnv`, `starship`, `atuin`, `zoxide`, `keychain` and the
      rest. Every one is optional; the shell config checks for each with
      `command -v` and skips what is absent.
- [ ] **WSL only: `win32yank.exe` and Git for Windows.** Neovim has no
      clipboard provider without the first; git cannot store credentials
      without the second. Both are detected automatically once present — see
      [Ubuntu under WSL](#per-platform-notes) below.
- [ ] **A Nerd Font.** `dot_config/ghostty/config` pins
      `CaskaydiaCove Nerd Font` by name, and `starship` and `eza --icons` need
      the glyphs. Nothing installs it for you on any platform now.
- [ ] **SSH key.** Restore `~/.ssh/id_ed25519` and add it to your agent
      (`ssh-add --apple-use-keychain` on macOS, plain `ssh-add` elsewhere).
      `keychain` manages it from there on, if you have installed it.
- [ ] **GPG signing key.** `~/.gitconfig` sets `commit.gpgsign = true` against
      a hardcoded `signingkey`, so **every commit fails until that key is in
      the keyring.** Import it, then check `echo test | gpg --clearsign`. You
      will need a `pinentry` your platform can drive.
- [ ] **Switch the remote back to SSH.**
      `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:evelyn-king/dotfiles.git`
- [ ] **Fill in `~/.config/shell/extras.sh`.** Machine-local settings and
      secrets; deliberately untracked. See [`shell-startup.md`](shell-startup.md).
      `~/.config/git/config.local` is the git equivalent.

## Per-platform notes

**macOS.** `path_helper` reorders PATH, which is why PATH is built in the
interactive rc rather than in `.zshenv` — see
[`shell-startup.md`](shell-startup.md). `credential.helper` renders as
`osxkeychain`.

**Ubuntu.** `git-credential-libsecret` is not on PATH by default; it has to be
built from `/usr/share/doc/git/contrib/credential/libsecret`. Until then, git
credential storage silently does nothing. Override in
`~/.config/git/config.local` if you would rather use `cache`.

**Arch.** Ships `git-credential-libsecret` with git itself, so that works out
of the box. If bash is the primary shell there, note that `~/.bashrc` carries
both the environment and the interactive setup — see
[`shell-startup.md`](shell-startup.md) for why the split differs from zsh's.

**Ubuntu under WSL.** Same packaging as native Ubuntu, different credentials.
`~/.gitconfig` routes `credential.helper` to Git Credential Manager on the
Windows side rather than to `libsecret`, so credentials are shared with Git for
Windows and survive a distro reinstall. This is not merely a preference:
a headless WSL session has no unlocked keyring, so `libsecret` there accepts
writes and then returns nothing — auth appears to succeed and silently keeps
re-prompting.

Requires **Git for Windows** on the host; it bundles GCM. The path is resolved
at apply time from these, in order:

```
/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe
/mnt/c/Program Files (x86)/Git/mingw64/bin/git-credential-manager.exe
/mnt/c/Program Files/Git/mingw64/libexec/git-core/git-credential-manager-core.exe
```

If none exists yet, the first is written as a default and `bootstrap.sh` warns.
Install Git for Windows, then re-run `chezmoi apply` to resolve it properly.

One implementation note, because it looks like a typo and is not: the rendered
value is `/mnt/c/Program\\ Files/...` with a doubled backslash. git parses `\\`
down to one backslash, then runs the helper through a shell, which needs the
space escaped. A plainly-quoted path parses fine and then fails at run time,
splitting at `Program`.

### Clipboard under WSL

**Install `win32yank.exe` and put it on PATH.** Neovim detects it on its own —
there is no configuration here to set — but without it Neovim has no clipboard
provider under WSL and yanks never reach the Windows clipboard.

tmux and zellij need nothing: `tmux.conf` sets `set-clipboard on` and zellij's
`copy_command` is left commented out, so both go through OSC 52 and the
terminal carries the text out. Neovim is the exception, and the reason is
worth knowing before you try to "fix" it in `dot_config/nvim`:

LazyVim sets `clipboard = "unnamedplus"`, which routes yanks to the system
clipboard and so requires a provider. Neovim's OSC 52 fallback — the one thing
that would work here with nothing installed — is explicitly skipped whenever
`&clipboard` is non-empty, because OSC 52 *paste* has to query the terminal and
blocks for up to ten seconds when the terminal declines to answer, which most
do. So the option that sends yanks to the clipboard is the same option that
disables the fallback that would have carried them.

The symptom is inconsistent rather than absent, which makes it easy to
misdiagnose: inside tmux it works by accident, because Neovim falls through to
the `$TMUX` branch, writes to a tmux buffer, and tmux forwards that over OSC 52
itself. Under zellij — which sets `$ZELLIJ`, not `$TMUX` — or in a bare
terminal, you get `clipboard: No clipboard tool` and silent failures.

`win32yank` also handles the line-ending translation (`-i --crlf` on the way
out, `-o --lf` on the way back), which the OSC 52 path does not.

Under WSLg, an installed `wl-clipboard` or `xclip` will win the provider search
before `win32yank` and works too, since WSLg syncs its clipboard with Windows.
Installing `win32yank` is the option that does not depend on WSLg being there.
