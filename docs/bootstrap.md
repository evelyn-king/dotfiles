# Bootstrapping a fresh Mac

```bash
curl -fsSL https://raw.githubusercontent.com/evelyn-king/dotfiles/main/bootstrap.sh | bash
```

That covers layers 0-3 below. Layer 4 is manual and is the checklist at the end.

## The four layers

Each layer is owned by exactly one thing. Knowing which one owns a given tool
is how you know where to change it.

| Layer | What | Owner |
|---|---|---|
| 0 | Xcode CLT, Determinate Nix, the clone | `bootstrap.sh` |
| 1 | the nix-darwin system closure | `bootstrap.sh`, then `darwin-rebuild` |
| 2 | dotfiles and chezmoi externals | `chezmoi apply` |
| 3 | language runtimes and global CLI tools | mise, via a `chezmoi apply` hook |
| 4 | GUI apps, SSH and GPG keys, secrets | you, using the checklist below |

Versions live in exactly two files: [`nix/flake.lock`](../nix/flake.lock) for
the system closure, and `~/.config/mise/mise.lock` — from
[`dot_config/mise/config.toml`](../dot_config/mise/config.toml) — for
everything above it.

## What `bootstrap.sh` does

It is idempotent; re-running it is safe and skips whatever is already done.

1. Refuses to run on anything but Apple silicon macOS — `nix/flake.nix`
   hardcodes `nixpkgs.hostPlatform = "aarch64-darwin"`.
2. Installs the Xcode Command Line Tools and waits for them.
3. Installs Determinate Nix, unless `/nix` already has it. The flake sets
   `nix.enable = false` and leaves the daemon and `/etc/nix/nix.conf` to
   Determinate; do not swap in a different installer without changing that.
4. Clones the repo to `~/.local/share/chezmoi` **over HTTPS**, because `origin`
   is an SSH remote and a fresh machine has no key yet.
5. Runs the first activation. `darwin-rebuild` does not exist yet — it arrives
   *in* the closure being built — so the first switch goes through
   `sudo nix run nix-darwin/master#darwin-rebuild -- switch`. Every switch after
   that is the plain command in [`nix-darwin.md`](nix-darwin.md).
6. Runs `chezmoi init --apply`, which lays down the dotfiles and triggers the
   layer-3 hooks.
7. Creates `~/.config/shell/extras.sh` mode `600` if it is missing.

### The one failure you should expect

The first `darwin-rebuild switch` commonly aborts with a complaint that
`/etc/zshrc`, `/etc/bashrc` or `/etc/zshenv` "would be clobbered". Those are
the Determinate installer's own files. Move each aside and re-run:

```bash
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
```

## Layer 3: mise

`chezmoi apply` runs `run_onchange_after_mise-install.sh.tmpl`, which is keyed
on the hash of `dot_config/mise/config.toml`. Adding a tool is a one-line edit
plus `chezmoi apply` — there is no separate command to remember.

```bash
mise install          # what the hook runs
mise ls               # what you have
mise upgrade --bump   # bump every pin, review the diff, commit
```

The pins are exact on purpose, the same contract `flake.lock` has for the
system. `mise upgrade --bump` rewrites `config.toml` in place, so an upgrade
arrives as one reviewable diff rather than as silent drift between machines.

`bun` and `uv` stay in the flake rather than in mise: they are the backends
mise shells out to for its `npm:` and `pipx:` tools, so installing them
*through* mise would be a needless ordering dependency.

## Layer 4: the manual checklist

- [ ] **GUI applications.** The list and the reasoning are in
      [`nix-darwin.md`](nix-darwin.md#applications-installed-by-hand). Ghostty
      first, since it reads `dot_config/ghostty`.
- [ ] **SSH key.** Restore `~/.ssh/id_ed25519`, then
      `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`. `dot_zshrc` has
      `keychain` manage it from there on.
- [ ] **GPG signing key.** `dot_gitconfig` sets `commit.gpgsign = true` against
      a hardcoded `signingkey`, so **every commit fails until that key is in
      the keyring.** Import it, then check `echo test | gpg --clearsign`.
      `pinentry_mac` is already in the closure.
- [ ] **Switch the remote back to SSH.**
      `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:evelyn-king/dotfiles.git`
- [ ] **Fill in `~/.config/shell/extras.sh`.** Machine-local settings and
      secrets; deliberately untracked. See [`shell-startup.md`](shell-startup.md).
- [ ] **Old fonts.** If this machine ever had the hand-installed
      `Caskaydia Cove Nerd Font Complete*.otf` in `~/Library/Fonts`, delete
      them — the flake now supplies `nerd-fonts.caskaydia-cove` and two copies
      of the same family compete.

## Migrating an existing machine

A machine built before mise took over layer 3 still has the old uv and bun
installs. `mise activate` prepends its own tool directories, so at an
interactive prompt the mise copy wins and the old one is merely dead weight —
but only for tools mise actually installed. If one entry fails to install, the
stale copy keeps answering and nothing tells you. Clear them out. After the
first `mise install`:

```bash
uv tool uninstall --all
rm -rf ~/.bun/install/global
rm -f ~/.local/bin/mise                    # the flake supplies it now
rm -f ~/.local/bin/sync-uv ~/.local/bin/sync-bun ~/.npmrc
```

That last line is needed because chezmoi does not delete a target just because
its source disappeared — there is no `.chezmoiremove` in this repo — so files
dropped from the source state linger until you remove them by hand.

Then clear the orphaned `~/.local/bin` symlinks left behind by uv — `ruff`,
`mypy`, `dmypy`, `mypyc`, `stubgen`, `stubtest`, `black`, `blackd`,
`pre-commit`, `conda-lock`, `unidep`, `markdown-code-runner`, `tuitorial`,
`python3.12`, and the broken `agent-cli`/`ag`/`agent` set whose venv is already
gone. Confirm with `type ruff codex opencode` that everything resolves through
mise.
