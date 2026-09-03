# Cold-start deployment

These procedures require an internet connection and an account that can approve
system changes. The first dry run downloads pinned externals when the chezmoi
cache is empty, even with `--refresh-externals=never`.

The current deployment paths are Apple Silicon macOS and Omarchy. Do not use
these instructions for native Windows. Its history lives on the `windows`
branch.

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
[package-lists/macos.md](package-lists/macos.md) before activation. The first
activation must use `nix run` because `darwin-rebuild` is not on `PATH` yet:

```bash
sudo nix run nix-darwin/master#darwin-rebuild -- \
  switch --flake "$(chezmoi source-path)/nix#macbook"
```

The activation removes the bootstrap Homebrew `chezmoi` formula because Nix
owns that command. Restart the Mac so the system generation, applications, and
fonts are available in a fresh login. Then run the second apply. This pass sees
the newly installed Emacs and mise commands, so it can install Doom and the
mise tool set.

```bash
sudo shutdown -r now
# Run after logging back in.
chezmoi apply
```

Open AeroSpace and grant its requested Accessibility permission. Launch the
managed applications that need first-use approval or account login. Complete
the Jupyter environment setup in the main README if this host will run
notebooks.

Run a third apply and the final checks:

```bash
chezmoi apply
chezmoi status
chezmoi apply --dry-run --refresh-externals=never
darwin-rebuild --list-generations
brew list --cask
mise doctor
zsh -ic 'bindkey -lL main; printf "KEYTIMEOUT=%s\n" "$KEYTIMEOUT"'
```

`chezmoi status` and the dry run should report no file changes. The drift hook
should print nothing after the activated generation matches the flake.

## Omarchy

Start from a working Omarchy desktop. The package and shell hooks require the
Omarchy 4 dispatcher, and the committed mise lock currently targets x86-64.
Check those prerequisites first:

```bash
test "$(uname -m)" = x86_64
command -v omarchy
omarchy version
command -v mise || omarchy pkg add mise
omarchy pkg add chezmoi
```

Stock Omarchy owns the `tldr` command. The package manifest deliberately leaves
out `tealdeer` because the two packages conflict.

Initialize the source, inspect it, and run the first apply:

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi source-path
chezmoi apply --dry-run --refresh-externals=never
chezmoi apply
```

The first apply installs required pacman packages, then mise tools and local
project trust. Optional AUR packages run last. Emacs arrives too late for the
Doom hook on this pass.

Set zsh as the login shell after the package hook installs it. This is required
for non-interactive SSH commands to receive the managed environment. Log out of
the desktop completely or reboot after `chsh` succeeds.

```bash
chsh -s "$(command -v zsh)"
sudo systemctl reboot
```

After logging back in, run the second apply so Doom installs. Complete the
interactive Tailscale and Dropbox steps in
[package-lists/omarchy-linux.md](package-lists/omarchy-linux.md). Complete the
Jupyter environment setup in the main README if this host will run notebooks.

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
