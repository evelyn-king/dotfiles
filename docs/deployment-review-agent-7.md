# Deployment review: agent 7 safety, privacy, and migration policy

Reviewed commit: `30923db41d1c2c3f0458b1b322d7b1509e538c6b`

Reviewed branch: `feat/port-of-work-profile`

Scope: generic and Linux behavior owned by agent 7. I did not review macOS
privacy approvals, Keychain behavior, or other macOS-only paths.

The safety verdict is `blocked`. The permanent removal policy can delete
unrelated files on a first apply. Mandatory Git signing also leaves a fresh
host unable to commit until the owner restores a particular secret key. The
Git agent hooks work for their tested examples, but simple shell wrappers and
common Git spellings bypass them.

The worktree already contained reports from other reviewers and `nvim.log` as
untracked files. I did not edit or remove them. This report is the only file I
added.

## Findings

### A7-001

Finding ID: A7-001

Severity: blocker

Platform and scenario: All platforms, first apply to an existing home or any
forced apply after a retired path has been reused

Deployment phase: Removal phase of every apply

Files and lines: `.chezmoiremove:1-83`

Observed behavior: `.chezmoiremove` declares 45 permanent removal targets.
Chezmoi removes directory targets recursively without checking contents or
provenance. In a disposable destination, it deleted an unrelated
`~/.config/themes/custom.conf` on the first apply. After I recreated the file,
`apply --force` deleted it again. A non-forced, noninteractive second apply
stopped at a conflict prompt and left the replacement intact.

Fresh-host consequence: A home restored from backup can lose a legitimate
`~/.gitconfig`, `~/.config/mise/config.toml`, executable in `~/.local/bin`, or
an entire `~/.config/themes` tree. The plan's safe-check command includes
`--force`, which removes the conflict protection on repeat applies.

Reproduction or evidence: Create a populated target under a disposable
destination, then run `chezmoi --source "$PWD" --destination "$review_home"
--persistent-state "$state" apply --force "$review_home/.config/themes"`.
Both first apply and forced repeat removed the populated directory. Agent 1
independently reports the same cause as A1-001.

Automated or manual: Automated and unconditional

Current workaround: Back up all listed paths and exclude removal entries from
the first apply. Do not use `--force` until the list has been audited against
the destination.

Recommended change: Expire the migration block at lines 30-83 once the owner
has confirmed that the old fleet has crossed the migration. Replace lines
8-28 with guarded, one-time migrations only where cleanup is still required.
Each guard should recognize the exact old file, link target, or generated
wrapper and leave unknown content alone. Ongoing ownership conflicts should
produce a drift warning instead of deleting a path forever. The recursive
`.config/themes` entry should not remain as persistent policy.

Verification: Seed every listed target with the known retired artifact, then
repeat with an unknown sentinel. The migration may remove the known artifact
once. It must preserve the sentinel on first, second, and forced applies.

Confidence: verified

### A7-002

Finding ID: A7-002

Severity: high

Platform and scenario: Generic Linux or Omarchy before GPG restoration, or a
host where `gpg` is absent when chezmoi renders the Git config

Deployment phase: First Git commit after apply

Files and lines: `dot_config/git/config.tmpl:3-6`,
`dot_config/git/config.tmpl:37-44`, `.chezmoitemplates/shell-interactive.sh:17`

Observed behavior: The config fixes one OpenPGP key ID and enables signing for
every commit. Rendering with no `gpg` on `PATH` succeeds and writes
`gpg.program = ""`. With GPG present and an empty isolated keyring, a commit
failed with `No secret key`. With the empty program, Git failed with `cannot
run : No such file or directory`. Neither case created a commit. Setting
`GPG_TTY` does not install the key, establish owner trust, or configure a
working pinentry.

Fresh-host consequence: Git appears configured, but every normal commit fails
until the owner diagnoses and repairs signing. The repo contains no key
restoration runbook and no preflight check that explains the missing command,
secret key, trust state, or pinentry.

Reproduction or evidence: Render `dot_config/git/config.tmpl` with an empty
`PATH`; inspect `gpg.program`. Render normally, point `GNUPGHOME` at an empty
mode-0700 directory, and commit in a disposable repository. Both negative
tests exited 128 and left the repository with zero commits. The review host
itself has GPG 2.4.9 and no secret keys.

Automated or manual: Configuration is automated. Secret-key import, trust,
pinentry validation, and recovery are undocumented manual work.

Current workaround: Put `[commit] gpgsign = false` in the later-loaded
`~/.config/git/config.local`, or pass `git -c commit.gpgsign=false` until the
key is restored.

Recommended change: Keep mandatory signing only if bootstrap has an explicit
preflight and restoration runbook. The preflight should check the resolved GPG
program, the full fingerprint rather than only a key ID, secret-key
availability, and a noninteractive signing probe. If unsigned setup commits
are acceptable, gate `commit.gpgsign` on an explicit host-local choice and
document how to turn it on after restoration.

Verification: On an empty Linux account, verify the preflight fails before Git
configuration claims readiness. Import the secret key and owner trust, test
pinentry in a terminal and a GUI-launched Git client, then create and verify a
signed commit. Repeat with GPG and pinentry separately absent.

Confidence: verified

### A7-003

Finding ID: A7-003

Severity: high

Platform and scenario: All platforms when Claude Code, Gemini CLI, or
OpenCode issues a destructive Git command through its shell tool

Deployment phase: Agent command execution

Files and lines: `.chezmoitemplates/git-rewrite-policy.py:11-36`,
`.chezmoitemplates/git-rewrite-policy.py:49-81`,
`.chezmoitemplates/git-rewrite-policy.py:133-205`,
`.chezmoitemplates/test_git_rewrite_policy.py:10-50`, `README.md:138-144`,
`dot_gemini/hooks/executable_block-git-rewrites.py.tmpl:33-63`,
`dot_config/opencode/plugins/block-git-rewrites.ts:16-36`

Observed behavior: The four shipped unit tests pass, and the Claude and Gemini
adapters block their direct test commands. The shared matcher still allows
`git reset --hard`, `git rebase`, `git add .`, a force refspec such as
`git push origin +feature`, `git push origin HEAD` while on `main`, and a
protected push nested in `bash -c` or `eval`. Gemini allows malformed input.
OpenCode also allows the command when Python or the Claude hook cannot run.

Fresh-host consequence: The README promises protection against history
rewrites, broad staging, protected-branch pushes, and PR merges. An agent can
perform three of those operations with ordinary alternate spellings. The
failure-open adapters make the protection disappear when their shared runtime
dependency is missing.

Reproduction or evidence: Run the policy with `runpy` and pass the commands
listed above to `check_command`. Each returned `None`. The direct forms
`git push --force origin feature`, `git push origin main`, `git add -A`, and
`gh pr merge 1` returned block reasons. Adapter protocol tests confirmed exit
2 for Claude and a JSON deny decision for Gemini.

Automated or manual: Automated but incomplete

Current workaround: Treat the hook as a warning layer. Review every agent Git
command and rely on remote branch protection for shared branches.

Recommended change: First decide the exact forbidden operations. Add tests for
every alternate spelling above, commands after `cd`, Git aliases, explicit
refspecs, and nested shells. A regex over a shell program cannot provide a
security boundary. Either reject nested interpreters conservatively or move
the protected operations behind a command wrapper with parsed arguments.
Make adapter failure behavior an explicit policy. If fail-open is intentional,
the README must say the hooks are advisory.

Verification: Run the same table through the shared function and all three
live adapters. Exercise a repository on `main`, one on a feature branch, and a
`cd other-repo && git push` command. Simulate missing Python and a missing hook
file.

Confidence: verified

### A7-004

Finding ID: A7-004

Severity: high

Platform and scenario: Fresh Omarchy host where the package hook installs
Tailscale, Dropbox, or Ollama as an ordinary package

Deployment phase: First apply and first login

Files and lines: `.chezmoidata/packages.yaml:17-18`,
`.chezmoidata/packages.yaml:34`, `.chezmoidata/packages.yaml:42`,
`run_after_install-omarchy-packages.sh.tmpl:24-30`; Omarchy 4.0.2
`/usr/share/omarchy/bin/omarchy-install-service-tailscale:7-20` and
`/usr/share/omarchy/bin/omarchy-install-service-dropbox:5-13`

Observed behavior: The repo calls the generic package helper for all three
packages. Omarchy's Tailscale service installer also enables `tailscaled`,
runs the browser authentication flow, grants the user operator permission,
enables Taildrop receive, and enables the bar plugin. Its Dropbox service
installer adds service dependencies, enables the bar plugin, and starts the
daemon. The repo performs none of those steps. It also installs Ollama without
enabling its service or pulling a model.

Fresh-host consequence: The first apply reports successful package
installation while the VPN, Dropbox client, and Ollama remain unusable. The
Tailscale omission matters most because it can be the route back into the new
host. Recovery needs privileged commands and browser authentication that the
repo does not document.

Reproduction or evidence: Compare the rendered package hook with the two
packaged Omarchy service installers. `omarchy-pkg-add` only runs
`pacman -S --needed`; it does not perform the service setup. Agent 3's manual
state inventory and A3-004, plus agent 4's A4-003, cover the Ollama overlap.

Automated or manual: Package installation is automated. Service enablement,
operator permission, authentication, plugin setup, and model download are
undocumented manual work.

Current workaround: After apply, run Omarchy's service installers or carry
out their steps by hand. Enable Ollama and pull a chosen model separately.

Recommended change: Do not start interactive authentication from an
unattended apply. Add a Linux post-apply checklist that names Omarchy's service
installers and explains each privilege and browser prompt. If these services
are required for the workstation verdict, add a non-destructive readiness
check that reports package, unit, authentication, and operator state.

Verification: On a disposable stock Omarchy account, apply once, then record
package state, unit state, Tailscale operator state, Dropbox authentication,
and an `ollama list` result. Follow the documented manual steps, reboot, and
repeat the checks without another undocumented command.

Confidence: verified

### A7-005

Finding ID: A7-005

Severity: medium

Platform and scenario: Linux remote Jupyter launch with `--token`, especially
on a multi-user host or one whose home directory is searchable by other users

Deployment phase: Runtime after deployment

Files and lines: `dot_local/bin/executable_jupyter-remote-lab:110-143`,
`dot_local/bin/executable_jupyter-remote-lab:230-265`, `README.md:151-176`

Observed behavior: A custom token is passed as a command-line argument. In an
isolated launch it appeared verbatim in the process command line and in the
runner's log. With umask 022, the state directory was mode 0755 and
`current.env`, the log, and the PID file were mode 0644. The README also tells
the user to retrieve the default tokenized URL from the log.

Fresh-host consequence: Another local user can read the bearer token through
the process list on Linux systems without procfs restrictions. If the home
path is traversable, that user can also read the log. Backups and diagnostics
can retain the token after the server exits.

Reproduction or evidence: Run the launcher with a disposable state directory,
umask 022, a fake environment runner, `--detach`, and a marker token. `ps -ww`
showed `--IdentityProvider.token=<marker>`, and `stat` reported 0644 for all
three files. The review account's home is mode 0700, which prevents cross-user
log traversal on this host but does not hide the process arguments.

Automated or manual: Automated once the user supplies a token

Current workaround: Use the default generated token, keep the home directory
mode 0700, restrict procfs, and delete old logs after the session.

Recommended change: Set umask 077 before creating Jupyter state and logs. Do
not place a supplied token in the process argument list. Accept it through a
mode-0600 temporary config or another input channel that Jupyter can consume
without copying it into argv. Document token and log cleanup.

Verification: Launch with a marker token. Confirm the marker is absent from
`ps`, `/proc/$pid/cmdline`, and world-readable files. Confirm every state file
is mode 0600 and its directory is mode 0700.

Confidence: verified

### A7-006

Finding ID: A7-006

Severity: medium

Platform and scenario: Any clone shared outside the owner, regardless of
deployment platform

Deployment phase: Source publication and clone

Files and lines: Reachable Git commit metadata, `.mailmap:1-2`, `AGENTS.md:60-64`

Observed behavior: The current tree contains only the intended personal name,
primary address, two personal mailmap aliases, and a public signing key ID.
Reachable commit history also contains two employer-domain author addresses.
That conflicts with the repository rule against employer addresses. A
`.mailmap` changes display output but does not remove raw commit metadata.

Fresh-host consequence: Every full clone receives the old addresses. If the
remote is public or later shared, it links the owner's personal repository to
those employers. Remote visibility could not be confirmed during this review.

Reproduction or evidence: Compare `git log --all --format='%ae%n%ce' | sort -u`
with `AGENTS.md:63-64`. I have not copied the employer addresses into this
report because doing so would repeat the policy violation.

Automated or manual: Historical metadata, replicated automatically by Git

Current workaround: Keep the remote private and avoid distributing full
clones. Mailmap canonicalization only changes normal display.

Recommended change: Decide whether the rule is prospective or applies to
history. If it applies to history, plan an owner-approved history rewrite,
credential and signature impact review, force-push coordination, and clone
replacement. If history is intentionally retained, amend the rule so it does
not claim a stronger privacy property than the repository has.

Verification: Scan every reachable ref after the policy decision. If rewritten,
confirm the old addresses are absent from local objects after expiry and from
the remote's advertised history.

Confidence: verified

### A7-007

Finding ID: A7-007

Severity: low

Platform and scenario: Any host where a user follows the repository's secret
storage advice or stages new files from the source root

Deployment phase: Local customization and later commits

Files and lines: `AGENTS.md:60-64`, `README.md:96-97`, `.gitignore:1-2`,
`.chezmoitemplates/shell-interactive.sh:242-248`

Observed behavior: The repository says secrets belong in the hand-written
`~/.config/shell/extras.sh`, then sources that file as code in every
interactive shell. It gives no creation command, required mode, backup policy,
or advice about exported long-lived credentials. The repository ignore file
only covers Neovim's lock and Python bytecode. Common local credential names,
`.env` files, and logs are visible to Git. `nvim.log` was already an untracked
example during this review.

Fresh-host consequence: A user can create the secret file with mode 0644 under
a permissive umask or accidentally stage a credential artifact from the
source root. Sourcing malformed or partly written content can also break every
interactive shell.

Reproduction or evidence: `git check-ignore` reports visible for `.env`,
`.env.local`, `credentials.json`, `auth.json`, `id_ed25519`, and `nvim.log`.
The shell template sources `extras.sh` without checking its mode.

Automated or manual: Manual and undocumented

Current workaround: Create `extras.sh` with mode 0600, keep the home directory
private, inspect `git status`, and stage files by explicit path.

Recommended change: Add a short local-secret runbook. Prefer credential stores
or tool-specific auth files over exported tokens in shell startup. If
`extras.sh` remains the escape hatch, show a mode-0600 creation command and a
safe-write pattern. Add narrow ignores for known generated files and a
high-confidence secret scan before push. Do not treat `.gitignore` as the only
secret control.

Verification: Create the documented file under umask 022 and confirm it still
lands at mode 0600. Run the secret scanner against the current tree and all
reachable commits. Seed each named generated file and confirm Git ignores only
the intended paths.

Confidence: verified

### A7-008

Finding ID: A7-008

Severity: low

Platform and scenario: Fresh host with an empty chezmoi external cache

Deployment phase: External download before files are applied

Files and lines: `dot_vim/pack/plugins/start/.chezmoiexternal.toml.tmpl:1-51`,
`.chezmoidata/versions.yaml:7-49`

Observed behavior: All six Vim plugin archives use commit-qualified GitHub
URLs, but none declares a content checksum. Chezmoi therefore has no
repository-owned digest with which to validate the downloaded archive before
Vim sources its code.

Fresh-host consequence: A bad response from the download path can place code
in Vim's startup path even though the URL contains the expected commit ID.
Commit-qualified URLs reduce accidental drift, but the URL text does not
authenticate the response body.

Reproduction or evidence: Render the external declaration and inspect each
archive table. Every table has `type`, `url`, `exact`, and
`stripComponents`; none has checksum metadata. The
[chezmoi external reference](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/)
documents `checksum.sha256` for this purpose.

Automated or manual: Automated download and later code execution

Current workaround: Trust HTTPS and GitHub's commit archive endpoint, then
inspect the populated cache manually.

Recommended change: Record a SHA-256 digest for each archive in the external
declaration. Update the commit and digest together. Agent 6 should merge this
with its review of Neovim's moving `stable` bootstrap and untracked plugin
lock.

Verification: Apply with an empty cache and confirm all six checksum checks
pass. Substitute a modified cached body and confirm chezmoi rejects it before
writing the destination.

Confidence: hypothesis

## Migration disposition

| Lines | Current purpose | Disposition |
| --- | --- | --- |
| 8-9 | Retired lazygit filename | Guard once by known old content, then remove the rule |
| 11-12 | Omarchy 3 menu stub | Guard once by the known stub, then remove the rule |
| 14-28 | Competing mise config, wrappers, and bash-preexec | Replace deletion with provenance checks and drift reports |
| 30-83 | Explicit legacy migration block | Expire after the owner's fleet checkpoint |
| 73-83 | Theme directory and plugin cleanup | Never leave as recursive permanent removal |

A bare `run_once` is not enough for a new clone. Its state is new too, so it
would still delete unknown pre-existing data. Content and provenance guards
must make the first run safe.

## Key and credential restoration inventory

| Item | Repository behavior | Required fresh-host work | Classification |
| --- | --- | --- | --- |
| SSH private key | Not tracked; keychain quietly ignores a missing `id_ed25519` | Restore or generate the key, set mode 0600, load it or configure forwarding, and verify the Git remote | Undocumented manual |
| GPG secret key | Public key ID is tracked; signing is mandatory | Install GPG and pinentry, import the secret key and owner trust, then test terminal and GUI signing | Undocumented manual, A7-002 |
| Linux Git HTTPS credentials | Uses `cache --timeout=3600` | Authenticate on first use; the helper keeps credentials in memory for one hour | Expected manual, undocumented |
| GitHub CLI | Package only | `gh auth login` | Undocumented manual |
| Gemini CLI | Selects API-key auth but stores no key | Supply and protect the API key | Undocumented manual |
| Claude, Codex, OpenCode, Google Cloud | Packages or config only | Complete each tool's login flow | Undocumented manual |
| Atuin | Sync of records is enabled | Register or log in and decide whether command-history sync is wanted | Undocumented manual |
| Bitwarden | Package and launcher only | Log in, unlock, and choose session handling | Undocumented manual |

The tracked name, email address, mailmap aliases, and OpenPGP key ID are public
identity data, not secret signing material. No SSH private key, GPG private
key, or credential file is tracked.

## Linux services and permissions inventory

| Item | Automated | Manual work or permission |
| --- | --- | --- |
| Tailscale | Package only | Root service enable, browser login, routes choice, user operator grant, Taildrop receiver, optional bar plugin |
| Dropbox | Base packages only | Missing service-installer dependencies, daemon start, browser login, optional bar plugin |
| Ollama | CUDA package only | Service enable and model downloads; hardware package choice is covered by A3-004 and A4-003 |
| Agent shell tools | Hooks are installed executable | Claude and OpenCode use automatic permission modes; the owner must accept that trust policy |
| Omarchy AUR installs | Package hook invokes the AUR helper | Review and execute third-party build recipes with elevated install privileges |

## Checks without findings

- A high-confidence secret-pattern scan found no private-key blocks, common
  GitHub or Slack tokens, or AWS access-key IDs in the current tree or 214
  reachable commits.
- The Linux Git credential helper is an in-memory cache, not a plaintext file
  store.
- `run_onchange_after_trust-local-projects-mise.sh.tmpl` trusts one
  repo-managed config whose only setting adds that project's `bin` directory
  to `PATH`. Its rendered hash changes with the config and the resolved mise
  executable. I found no broad trusted-path rule.
- The Doom checkout uses a fixed Git object ID. Linux mise binary downloads in
  the committed lock carry SHA-256 checksums. Those are better download
  controls than the Vim external declarations.
- The Claude and Gemini hook templates render as valid Python. All run-script
  templates pass `bash -n`. The rendered Git config parses.

## Cross-workstream handoff

The Jupyter permission test exposed a separate agent 6 issue. On a fresh state
path, detached launch redirects the child log and writes the PID at lines
253-254 before `write_runtime_env` creates `STATE_DIR` at line 113. The command
failed immediately with `No such file or directory`. Precreating the state
directory allowed the permission test to continue. Agent 6 independently
classified this first-run failure as A6-002, so the coordinator should use that
finding rather than duplicate it from this report.

## Verification record and limits

Commands completed successfully:

- `git status --short --branch`, `git rev-parse HEAD`,
  `git branch --show-current`, and `git diff --check`
- `chezmoi apply --dry-run --force --verbose --refresh-externals=never`
- `bash -n` on every rendered `run_*.tmpl`
- Python compilation of both rendered hook adapters
- `.chezmoitemplates/test_git_rewrite_policy.py`, four tests passing
- Git config render and parse
- disposable removal, signing, hook-policy, and Jupyter permission tests

I did not run a destructive apply against the real home, import the owner's
GPG key, change system services, authenticate accounts, or test a disposable
cold-start VM. The pinentry test still needs an interactive terminal and a GUI
client. Remote repository visibility was not established. Omarchy service
comparison used the installed Omarchy 4.0.2 tree and must be repeated against
the exact cold-start image.
