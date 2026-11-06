# macOS package list

Apple Silicon macOS machines use Homebrew. The declaration is
[`homebrew/Brewfile`](../../homebrew/Brewfile), which is repository content
rather than a home file and is listed in `.chezmoiignore`. Read the Brewfile for
the actual formula, cask and App Store lists. This page covers only the
ownership rules and the manual steps around them.

```bash
brew-switch       # install, upgrade, then remove anything undeclared
dotfiles-doctor   # report drift without changing anything
```

`brew-switch` is installed in `~/.local/bin` with the source path already
resolved, so it works from any directory. `chezmoi apply` never runs it.

## Ownership

| Source | Owns |
| --- | --- |
| `homebrew/Brewfile` `brew` entries | system CLI packages and build libraries |
| `homebrew/Brewfile` `cask` entries | GUI applications and fonts |
| `homebrew/Brewfile` `mas` entries | Mac App Store applications |
| `dot_config/mise/conf.d/10-dotfiles.toml` | language runtimes and global CLI tools |

Anything mise manages is deliberately absent from the Brewfile. So is mise
itself: chezmoi installs the pinned release into `~/.local/bin`.

The Xcode Command Line Tools supply `cc`, `c++`, the linker and the related
build commands. GCC is not installed globally, because its unprefixed commands
would replace Apple's toolchain on `PATH`.

The Brewfile owns every formula, cask and tap in the Homebrew prefix. After a
successful install, `brew-switch` removes each one the Brewfile does not
declare. Add a package to the Brewfile before installing it with Homebrew if it
has to survive the next `brew-switch`. Homebrew itself must already be
installed; the cold-start guide covers that.

Cleanup is limited to formulae, casks and taps. Mac App Store apps and cargo,
go, npm and uv packages are left alone. Do not substitute
`brew bundle install --force-cleanup`: it also uninstalls every App Store app
and language package the Brewfile does not list.

## PATH

Homebrew installs GNU coreutils and gawk with a `g` prefix (`gls`, `gdate`,
`gawk`), and leaves sqlite and libxml2 unlinked because macOS ships older
copies. `shell-path.sh` puts their `gnubin` and `opt/.../bin` directories ahead
of `/opt/homebrew/bin`, so `ls`, `date`, `awk`, `sqlite3` and `xmllint` resolve
to the Homebrew versions rather than those in `/usr/bin`. Remove a line there to
fall back to the macOS command.

Do not add `brew shellenv` to a startup file. The shell builds the Homebrew
paths itself; [shell-startup.md](../shell-startup.md) explains why.

## Third-party taps

Homebrew refuses to load a cask or formula from an untrusted tap. Declare each
third-party entry with its full tap name and `trusted: true`, as the AeroSpace
and Omarchy casks are. `brew-switch` records that trust before it installs
anything, and its cleanup resets Homebrew's trust store to exactly the entries
the Brewfile declares.

## Cask update policy

Casks are non-greedy, the `brew bundle` default. Nearly all of the declared
casks set `auto_updates`, so each vendor's own updater owns its version and
`brew-switch` leaves it alone. That avoids a fortnightly fight with those
updaters, and avoids re-running vendor `pkg` installers under `sudo`. Ordinary
upgrades still pick up the handful of casks that do not update themselves.

Two casks opt back in with `greedy: true`, because they sat months out of date
under their own updaters despite advertising `auto_updates`. The Brewfile marks
them inline. Close a greedy cask's application before running `brew-switch`,
since an upgrade can replace a running bundle.

AeroSpace starts at login after its first launch, but macOS still requires a
one-time Accessibility approval. The cold-start guide records that handoff and
the command that verifies the running application.

## Adopt existing applications

Before the first `brew-switch` on an existing Mac, let Homebrew adopt
applications installed by another method. Otherwise cask installation stops
when it finds the existing application in `/Applications`.

Derive the cask list from the Brewfile rather than from a list written here. A
hardcoded list goes stale on the next cask change. Start a clean Bash session for
these commands so the cask list splits into separate arguments even when your
login shell is zsh:

```bash
/bin/bash --noprofile --norc
brewfile="$(chezmoi source-path)/homebrew/Brewfile"
casks=$(brew bundle list --file "$brewfile" --casks)
printf '%s\n' "$casks"
comm -23 <(printf '%s\n' $casks | sed 's|.*/||' | sort) <(brew list --cask | sort)
```

The last command lists declared casks Homebrew does not yet manage, including
missing applications and possible collisions. Third-party casks, the ones with a
tap prefix, have to be trusted before Homebrew will load them. Continue in the
same Bash session only after the listing succeeds and you have reviewed it:

```bash
brew trust --cask $(printf '%s\n' $casks | grep /)
brew install --cask --adopt $casks
brew list --cask
exit
```

Homebrew attempts to adopt existing app bundles, installs missing casks, and
skips casks it already manages. Adoption can reject a different bundle version
for an app that does not self-update, and `pkg` artifacts still run their
installers. Resolve each failure before running `brew-switch`. This procedure
has not yet passed an existing-Mac migration test. To skip a cask, remove its
declaration from the Brewfile first.

## Mac App Store applications

The Brewfile's `mas` entries declare the App Store applications, and the `mas`
formula, declared in the same file, installs them.

Sign in to the App Store before the first `brew-switch`. The account that owns
these purchases has to be signed in, or Homebrew cannot install or upgrade
them. `mas signin` does not work on current macOS, so sign in through the App
Store application. The repository cannot automate this.

Xcode is one of the declared applications and is a multi-gigabyte download, so
it adds noticeable time to the first `brew-switch`. It is separate from the
Xcode Command Line Tools that the cold-start guide installs with
`xcode-select --install`; those tools are the compiler and linker the rest of
this configuration depends on, and installing Xcode does not remove the need for
them. Launch Xcode once after it installs to accept its license.

Removing a `mas` entry does not uninstall the application, because `brew-switch`
limits cleanup to formulae, casks and taps. Delete those by hand.

Get the id for a new entry from the installed bundle:

```bash
mdls -name kMDItemAppStoreAdamID -raw /Applications/<name>.app
```

## Drift

Run `dotfiles-doctor` to compare Homebrew against the Brewfile. It reports
declared entries that are not installed and formulae, casks or taps that the
Brewfile does not declare. Outdated packages are not drift, since `brew-switch`
upgrades them. The doctor also warns while a Nix installation remains, and
reports duplicate user-installed copies of mise tools and old mise versions
eligible for pruning. It removes nothing. Routine `chezmoi apply` prints a
reminder without running these checks.

## Migrate from nix-darwin

A Mac that ran the former nix-darwin flake still has Nix's copies of the CLI
tools, fonts and Proton Mail Bridge. Homebrew has to provide its replacements
before Nix is removed, so follow these steps in order.

1. Apply the dotfiles. This installs `brew-switch` and the new PATH order. Until
   Nix is gone, nix-darwin's `/etc/zshrc` still appends its command directory,
   now behind Homebrew, so its tools keep working in the meantime.

   ```bash
   chezmoi apply
   ```

2. Quit Proton Mail Bridge, then install everything the Brewfile declares. Apply
   once more, because some templates render differently once their tools are
   installed. Open a new terminal afterwards.

   ```bash
   brew-switch
   chezmoi apply
   ```

3. Confirm that the commands Nix provided now resolve under `/opt/homebrew`, and
   that the doctor's only warning is the leftover Nix installation:

   ```bash
   command -v ls awk sqlite3 rg nvim gpg
   dotfiles-doctor
   ```

4. Remove nix-darwin, which restores the stock `/etc` shell files, then remove
   Determinate Nix itself:

   ```bash
   sudo nix run nix-darwin/master#darwin-uninstaller
   sudo /nix/nix-installer uninstall
   ```

5. Restart, start Proton Mail Bridge from `/Applications`, re-enable it as a
   login item if it was one, and run `dotfiles-doctor` again. It should report
   no Nix or Homebrew warnings.

Before step 4, checking out an older commit and activating the flake from it
still restores the previous system. After step 4, the Brewfile is the only
declaration.

Homebrew's `gnupg` uses the terminal pinentry by default. If commit signing
should prompt in a dialog, add this line to `~/.gnupg/gpg-agent.conf` and run
`gpgconf --kill gpg-agent`, then rerun `git-signing-preflight`:

```text
pinentry-program /opt/homebrew/bin/pinentry-mac
```
