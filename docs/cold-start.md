# Cold-start deployment

These procedures require an internet connection and an account that can approve
system changes. The first dry run downloads pinned externals when the chezmoi
cache is empty, even with `--refresh-externals=never`.

The supported deployment targets are Apple Silicon macOS, Omarchy 4 on
x86_64 and aarch64 Linux, and Ubuntu 26.04 x86_64 headless hosts. Native Windows lives on the
`windows` branch.

When validating a PR before merge, add `--branch <candidate-branch>` to each
`chezmoi init` below. Otherwise init selects the public default branch. Record
the tested commit with `git -C "$(chezmoi source-path)" rev-parse HEAD`.

## Apple Silicon macOS

Homebrew owns the macOS packages, declared in `homebrew/Brewfile`. The
procedure expects the primary account `evelynking`. Confirm the machine before
changing it:

```bash
test "$(uname -m)" = arm64
test "$(id -un)" = evelynking
xcode-select --install
```

Wait for the Command Line Tools installation to finish. Install Homebrew and
use its path for this terminal only. Do not append `brew shellenv` to
`~/.zprofile`; this repo manages that file and builds the Homebrew paths itself.

```bash
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
brew --version
brew install chezmoi
```

The Brewfile declares `chezmoi` too, so Homebrew keeps managing this bootstrap
copy.

Initialize the public source repo without applying it, then inspect the first
apply. The apply installs the pinned mise release and its tool set into your
home directory, and puts `brew-switch` in `~/.local/bin`.

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi source-path
chezmoi apply --dry-run --refresh-externals=never
chezmoi apply
```

If this is an existing Mac, complete the cask adoption procedure in
[package-lists/macos.md](package-lists/macos.md) first. A Mac that ran the
former nix-darwin flake follows the migration steps on that page instead of the
rest of this section.

Sign in to the App Store through the App Store application, using the account
that owns the Brewfile's `mas` entries. Homebrew cannot install or upgrade them
otherwise. Xcode is one of them, so expect a multi-gigabyte download during the
step below, and launch it once afterwards to accept its license.

Install everything the Brewfile declares, then apply again. Some templates
render differently once their tools are installed. Open a new terminal
afterwards so the shell picks up the Homebrew paths.

```bash
"$HOME/.local/bin/brew-switch"
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
chezmoi status --exclude=scripts
chezmoi diff --exclude=scripts
chezmoi apply --dry-run --refresh-externals=never
dotfiles-doctor
brew list --cask
mise doctor
aerospace list-workspaces --all
zsh -ic 'bindkey -lL main; printf "KEYTIMEOUT=%s\n" "$KEYTIMEOUT"'
```

The status and diff commands should print nothing. Excluding scripts checks
file convergence without listing the hooks that run on every apply. The dry
run should succeed. `dotfiles-doctor` prints progress and an explicit result for each
check. Resolve any WARN messages and review SKIP messages for checks that could
not run. Matching configuration should produce OK results.

## Omarchy 4 x86_64 or aarch64

Start from a working Omarchy desktop. The package and shell hooks need the
Omarchy 4 dispatcher, and the committed mise lock targets x86-64 and aarch64.
Check both first:

```bash
case "$(uname -m)" in x86_64|aarch64) ;; *) false ;; esac
command -v omarchy
omarchy version
omarchy update system-pkgs
omarchy pkg add chezmoi
```

The ISO can start without synchronized package indexes. Complete the system
package update before installing bootstrap tools; it refreshes the indexes and
upgrades installed packages together.

Check the [Vulkan provider prerequisite](package-lists/omarchy-linux.md#system-packages)
before applying. Omarchy usually installs the provider during hardware setup,
but a VM may need an explicit choice.

Initialize the source, inspect it, and run the first apply:

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi source-path
chezmoi apply --dry-run --refresh-externals=never
chezmoi apply
```

The first apply installs the pinned mise release into `~/.local/bin`, then the
required pacman packages, mise tools, and local project trust, then the
optional AUR packages.

Set zsh as the login shell once the package hook has installed it. Without
this, non-interactive SSH commands never see the managed environment. Log out of
the desktop completely, or reboot, after `chsh` succeeds.

```bash
chsh -s "$(command -v zsh)"
sudo systemctl reboot
```

After logging back in, run the second apply to resolve executable paths in
templates against the installed tools. Then complete the
interactive Tailscale and Dropbox steps in
[package-lists/omarchy-linux.md](package-lists/omarchy-linux.md), and the Jupyter
environment setup in the main README if this host will run notebooks.

```bash
chezmoi apply
```

Run a third apply and the final local checks:

```bash
chezmoi apply
chezmoi status --exclude=scripts
chezmoi diff --exclude=scripts
chezmoi apply --dry-run --refresh-externals=never
getent passwd "$USER" | cut -d: -f7
mise doctor
zsh -ic 'bindkey -lL main; printf "KEYTIMEOUT=%s\n" "$KEYTIMEOUT"'
hyprctl configerrors
```

The login-shell check should print the path returned by `command -v zsh`.
The status and diff commands should print nothing. Excluding scripts checks
file convergence without listing the hooks that run on every apply. The dry
run should succeed. Review any tool-drift warnings separately using the
[mise ownership guidance](package-lists/mise.md). From another machine, verify
that an SSH command receives the managed environment:

```bash
ssh <host> 'printf "%s %s\n" "$MAMBA_ROOT_PREFIX" "$LANG"; printf "%s\n" "$PATH"'
```

## Ubuntu 26.04 x86_64, headless

Start with an account that has sudo access and a working SSH login. The native
package hook uses sudo only when packages need installation. It does not create
accounts, configure the SSH server, or change firewall rules.

Check the target and install the small set of bootstrap prerequisites:

```bash
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 26.04
test "$(uname -m)" = x86_64
sudo apt-get update
sudo apt-get install --no-install-recommends ca-certificates curl git unzip
```

Install chezmoi with its upstream user installer:

```bash
mkdir -p ~/.local/bin
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
chezmoi --version
```

Initialize the source, then run its mise install hook on its own. The hook
installs the pinned mise release into `~/.local/bin` before any apply, so the
package preview below uses the same mise as the apply. The managed shell files
provide mise activation after apply.

```bash
chezmoi init https://github.com/evelyn-king/dotfiles.git
chezmoi execute-template \
  --file "$(chezmoi source-path)/run_before_00-install-mise.sh.tmpl" | bash
mise --version
mise bootstrap files apply --help
```

Inspect both the file changes and the package plan. The Ubuntu package
declarations require the Ubuntu `universe` component. If the package preview
reports unavailable entries, check that component and refresh APT metadata
before proceeding.

```bash
chezmoi apply --dry-run --refresh-externals=never
MISE_CONFIG_DIR="$(chezmoi source-path)/dot_config/mise" \
  MISE_SYSTEM_PACKAGES_MANAGERS=apt \
  mise --cd / bootstrap --only files,packages --dry-run
chezmoi apply
```

The Ubuntu before-hook disables APT recommendations globally, then restores
native packages with their required dependencies. After writing dotfiles,
chezmoi installs the locked mise tools and trusts the managed project-root
environment. Ubuntu skips the desktop configs.

Set the login shell, then reconnect so SSH starts the managed zsh environment:

```bash
chsh -s "$(command -v zsh)"
exit
```

From a new SSH session, apply again so path-sensitive templates see the installed
tools. A further apply should converge:

```bash
chezmoi apply
chezmoi apply
chezmoi status --exclude=scripts
chezmoi diff --exclude=scripts
chezmoi apply --dry-run --refresh-externals=never
mise doctor
getent passwd "$USER" | cut -d: -f7
```

From another machine, check non-interactive SSH, which must find the same tools:

```bash
ssh <host> 'command -v node python bun uv fd bat; printf "%s\n" "$LANG"'
ssh <host> 'command -v jupyter-remote-lab; infocmp "$TERM" >/dev/null'
```

Check Neovim with `:checkhealth`.
The Jupyter launcher needs the environments described in the README before it
can start a notebook server. SSH keys and Git signing remain manual setup below.
See [Ubuntu package ownership](package-lists/ubuntu-linux.md) for update behavior.

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

keychain is installed on every supported host. On macOS launchd usually answers first,
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
