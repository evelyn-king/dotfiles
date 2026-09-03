# Repository guidelines

## Project structure
- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`.
- The repo root is the chezmoi source state for files under `$HOME`.
- `.chezmoidata/` carries template data; `.chezmoitemplates/` carries bodies shared
  between several rendered files.
- `nix/`, `docs/`, `scripts/` and the top-level Markdown are repo content. They are
  listed in `.chezmoiignore` and never applied to `$HOME`.

## Branching
- Keep macOS/Linux configs on `main`.
- Use the separate `windows` branch for native Windows history.

## Commands
- `chezmoi apply` applies the dotfiles from the configured source tree.
- `chezmoi apply --dry-run --refresh-externals=never` previews changes without
  updating pinned externals.
- `chezmoi execute-template --file <path>` renders a template for verification.
- `python3 -m pytest .chezmoitemplates/test_git_rewrite_policy.py` covers the shared
  agent git-safety policy.

## Style and naming
- YAML uses 2-space indentation; keep list ordering stable in `.chezmoidata/*.yaml`.
- Keep config files in their chezmoi destination layout at the repo root (for
  example, `dot_config/starship.toml`).
- Shared shell bodies in `.chezmoitemplates/` are included into both zsh and bash
  startup files, so they must stay POSIX: no arrays, no zsh glob qualifiers.
- Environment files follow `<name>_environment.yml` (for example,
  `analysis_environment.yml`).

## Editing rules
- Edit shared shell bodies in `.chezmoitemplates/shell-*.sh`, never the rendered
  `dot_zshrc.tmpl` / `dot_bashrc.tmpl` copies of them.
- Edit the agent git policy in `.chezmoitemplates/git-rewrite-policy.py`, never the
  per-tool hook adapters that include it.
- Edit Omarchy detection in `.chezmoitemplates/omarchy-detect.tmpl`, never the
  `$omarchy` variables in `.chezmoiignore.tmpl` and
  `dot_config/ghostty/config.tmpl` that include it.
- Declare runtimes and global CLI tools in `dot_config/mise/conf.d/`, Omarchy
  system packages in `.chezmoidata/packages.yaml`, and macOS system packages
  in `nix/flake.nix`. Do not declare the same tool in mise and a system package
  list.
- `dot_config/mise/mise.lock` and `nix/flake.lock` are repo content. Never apply
  them to `$HOME`; mise rewrites its lock in place and a second copy diverges.

## Testing
- There is no full automated test suite in this repo.
- For changes that affect installation, run
  `chezmoi apply --dry-run --refresh-externals=never` and verify the rendered
  dotfiles.
- For a template change, `chezmoi execute-template --file <path>` is faster than a
  dry-run apply.

## Commits and pull requests
- Commit messages are short, imperative summaries without prefixes (for example,
  `Update lazy.nvim config`, `Add mambarc`).
- PRs should include a brief summary, affected tools or paths, and how you verified
  changes (for example, `chezmoi apply --dry-run --refresh-externals=never`).
- Link related issues. Add screenshots only for UI-facing config changes.

## Configuration and security
- Do not commit secrets. They belong in the untracked
  `~/.config/shell/extras.sh`.
- This is a personal repo. Do not add employer hostnames, addresses, signing keys
  or internal paths to it.
- Put native Windows changes on the `windows` branch.
- Keep `dot_config/nvim/lazy-lock.json` untracked; it is per-machine.
