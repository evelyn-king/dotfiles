# Repository Guidelines

## Project Structure & Module Organization
- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`.
- The repo root is the chezmoi source state for files under `$HOME`.
- `.chezmoidata/` carries template data; `.chezmoitemplates/` carries bodies shared
  between several rendered files.
- `nix/`, `docs/`, `scripts/` and the top-level Markdown are repo content. They are
  listed in `.chezmoiignore` and never applied to `$HOME`.

## Branching
- Keep macOS/Linux configs on `main`.
- Use the separate `windows` branch for native Windows history.

## Build, Test, and Development Commands
- `chezmoi apply` applies the dotfiles using the configured source tree.
- `chezmoi apply --dry-run --refresh-externals=never` previews changes without
  updating pinned externals.
- `chezmoi execute-template --file <path>` renders a template for verification.
- `python3 -m pytest .chezmoitemplates/test_git_rewrite_policy.py` covers the shared
  agent git-safety policy.

## Coding Style & Naming Conventions
- YAML uses 2-space indentation; keep list ordering stable in `.chezmoidata/*.yaml`.
- Keep config files in their chezmoi destination layout at the repo root (for
  example, `dot_config/starship.toml`).
- Shared shell bodies in `.chezmoitemplates/` are included into both zsh and bash
  startup files, so they must stay POSIX: no arrays, no zsh glob qualifiers.
- Environment files follow `<name>_environment.yml` (for example,
  `analysis_environment.yml`).

## Editing Rules
- Edit shared shell bodies in `.chezmoitemplates/shell-*.sh`, never the rendered
  `dot_zshrc.tmpl` / `dot_bashrc.tmpl` copies of them.
- Edit the agent git policy in `.chezmoitemplates/git-rewrite-policy.py`, never the
  per-tool hook adapters that include it.
- Declare tools in `dot_config/mise/conf.d/`, macOS system packages in
  `nix/flake.nix`. Do not add a package to both.
- `dot_config/mise/mise.lock` and `nix/flake.lock` are repo content. Never apply
  them to `$HOME`; mise rewrites its lock in place and a second copy diverges.

## Testing Guidelines
- There is no full automated test suite in this repo.
- For changes that affect installation, run
  `chezmoi apply --dry-run --refresh-externals=never` and verify the rendered
  dotfiles.
- For a template change, `chezmoi execute-template --file <path>` is faster than a
  dry-run apply.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries without prefixes (for example,
  `Update lazy.nvim config`, `Add mambarc`).
- PRs should include a brief summary, affected tools or paths, and how you verified
  changes (for example, `chezmoi apply --dry-run --refresh-externals=never`).
- Link related issues if applicable; add screenshots only for UI-facing config
  changes.

## Configuration & Security Notes
- Avoid committing secrets. Secrets belong in the age-encrypted file described in
  `docs/encryption.md`, or in the untracked `~/.config/shell/extras.sh`.
- Public age recipients are not secret and are committed; private identities live
  only in `~/.config/chezmoi/`.
- This is a personal repo. Do not add employer hostnames, addresses, signing keys
  or internal paths to it.
- Put native Windows changes on the `windows` branch.
- Keep `dot_config/nvim/lazy-lock.json` untracked; it is per-machine.
