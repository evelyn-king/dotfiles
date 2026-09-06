# Cold-start deployment

These procedures require an internet connection and an account that can approve
system changes. The first dry run downloads pinned externals when the chezmoi
cache is empty, even with `--refresh-externals=never`.

The supported deployment targets are Apple Silicon macOS and Omarchy 4 on
x86_64 Linux. Native Windows lives on the `windows` branch.

## Apple Silicon macOS

This configuration is named `macbook`, targets `aarch64-darwin`, and sets the
primary account to `evelynking`. Confirm the machine before changing it:

```bash
test "$(uname -m)" = arm64
test "$(id -un)" = evelynking
xcode-select --install
```

Wait for the Command Line Tools installation to finish. Install Determinate
Nix, then open a new terminal and verify it:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install
nix --version
```

Install Homebrew and use its path for this terminal only. Do not append
`brew shellenv` to `~/.zprofile`; this repo manages that file and builds the
Homebrew paths itself.

```bash
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
brew --version
brew install chezmoi
```

Initialize the public source repo without applying it, then inspect the first
apply:

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi source-path
chezmoi apply --dry-run --refresh-externals=never
chezmoi apply
```

If this is an existing Mac, complete the cask adoption procedure in
[package-lists/macos.md](package-lists/macos.md) before activation.

Sign in to the App Store through the App Store application, using the account
that owns the declared `masApps`. Activation cannot install or upgrade them
otherwise. Xcode is one of them, so expect a multi-gigabyte download during the
activation below, and launch it once afterwards to accept its license.

The first activation must use `nix run` because `darwin-rebuild` is not on
`PATH` yet:

```bash
sudo nix run nix-darwin/master#darwin-rebuild -- \
  switch --flake "$(chezmoi source-path)/nix#macbook"
```

Activation removes the bootstrap Homebrew `chezmoi` formula, because Nix owns
that command now. Restart the Mac so the system generation, applications and
fonts are available in a fresh login. The second apply sees the newly installed
Emacs and mise commands, so it can install Doom and the mise tool set.

```bash
sudo shutdown -r now
# Run after logging back in.
chezmoi apply
```

Open AeroSpace once. In System Settings, go to Privacy & Security >
Accessibility, enable AeroSpace, then restart it. Its managed configuration
starts it at login from then on. Launch the other managed applications that need
first-use approval or an account login. If this host will run notebooks,
complete the Jupyter environment setup in the main README.

Run a third apply and the final checks:

```bash
chezmoi apply
chezmoi status
chezmoi apply --dry-run --refresh-externals=never
darwin-rebuild --list-generations
brew list --cask
mise doctor
aerospace list-workspaces --all
zsh -ic 'bindkey -lL main; printf "KEYTIMEOUT=%s\n" "$KEYTIMEOUT"'
```

`chezmoi status` and the dry run should report no file changes. The drift hook
should print nothing after the activated generation matches the flake.

## Omarchy 4 x86_64

Start from a working Omarchy desktop. The package and shell hooks need the
Omarchy 4 dispatcher, and the committed mise lock targets x86-64. Check both
first:

```bash
test "$(uname -m)" = x86_64
command -v omarchy
omarchy version
omarchy update system-pkgs
command -v mise || omarchy pkg add mise
omarchy pkg add chezmoi
```

The ISO can start without synchronized package indexes. Complete the system
package update before installing bootstrap tools; it refreshes the indexes and
upgrades installed packages together.

Initialize the source, inspect it, and run the first apply:

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi source-path
chezmoi apply --dry-run --refresh-externals=never
chezmoi apply
```

The first apply installs the required pacman packages, then mise tools and
local project trust, then the optional AUR packages. Emacs arrives too late for
the Doom hook on this pass, which is why there is a second apply below.

Set zsh as the login shell once the package hook has installed it. Without
this, non-interactive SSH commands never see the managed environment. Log out of
the desktop completely, or reboot, after `chsh` succeeds.

```bash
chsh -s "$(command -v zsh)"
sudo systemctl reboot
```

After logging back in, run the second apply so Doom installs. Then complete the
interactive Tailscale and Dropbox steps in
[package-lists/omarchy-linux.md](package-lists/omarchy-linux.md), and the Jupyter
environment setup in the main README if this host will run notebooks.

```bash
chezmoi apply
```

Run a third apply and the final local checks:

```bash
chezmoi apply
chezmoi status
chezmoi apply --dry-run --refresh-externals=never
getent passwd "$USER" | cut -d: -f7
mise doctor
zsh -ic 'bindkey -lL main; printf "KEYTIMEOUT=%s\n" "$KEYTIMEOUT"'
hyprctl configerrors
```

The login-shell check should print the path returned by `command -v zsh`.
`chezmoi status` and the dry run should report no file changes. From another
machine, verify that an SSH command receives the managed environment:

```bash
ssh <host> 'printf "%s %s\n" "$MAMBA_ROOT_PREFIX" "$LANG"; printf "%s\n" "$PATH"'
```

## SSH keys

Each host gets its own key. Nothing is copied between machines, so revoking a
lost or retired host means removing one public key instead of rotating a shared
identity.

```bash
ssh-keygen -t ed25519 -C "$(id -un)@$(hostname -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Register the public key with GitHub and any servers this host reaches, then
verify:

```bash
ssh -T git@github.com
```

Keep the filename `id_ed25519`. Interactive shell startup keeps any inherited
agent that answers `ssh-add -l`, which covers OpenSSH forwarding, Apple's launchd
agent, systemd sockets and password managers. Only when no agent answers does it
fall back to `keychain --ignore-missing id_ed25519`, and that fallback loads
exactly that name. A key called anything else is never picked up.

keychain is installed on both platforms. On macOS launchd usually answers first,
so keychain rarely runs. Store the passphrase there with
`ssh-add --apple-use-keychain ~/.ssh/id_ed25519`.

`~/.ssh/config` and key material are not managed by this repository.

## Git commit signing

A fresh host creates unsigned commits until the signing key and pinentry work.
After the platform setup installs GPG, restore the secret key from its secure
backup. Keep the backup and any exported owner-trust data out of this
repository.

Confirm the imported key has ultimate owner trust. If it does not, run
`gpg --edit-key B1DD4047A0B58992573E7C5F08B79F9C4FA6D2E1 trust` and choose
ultimate trust. Then run the signing probe from a terminal:

```bash
chezmoi apply
git-signing-preflight
```

The probe checks the configured full fingerprint, GPG executable, secret key,
owner trust, agent, pinentry, and a disposable signature. Only enable signing
after it passes:

```bash
git config --file ~/.config/git/config.local commit.gpgsign true
test "$(git config --get commit.gpgsign)" = true
```

The machine-local override is not managed by chezmoi. Test the next terminal
commit and the next commit from each GUI Git client, then check them with
`git log --show-signature -1`. Run
`git config --file ~/.config/git/config.local --unset-all commit.gpgsign` to
return the host to unsigned commits.
