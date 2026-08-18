# Repository Guidelines

## Project Structure & Module Organization
- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`.
- The repo root is the chezmoi source state for files under `$HOME`.
- `.chezmoidata/` carries template data (`versions.yaml`).
- `nix/` holds the nix-darwin flake that declares system packages. It is repo content, not a dotfile, so it is listed in `.chezmoiignore`; see `docs/nix-darwin.md`.
- `dot_config/mise/conf.d/10-dotfiles.toml` declares language runtimes and global CLI tools, pinned. It is the counterpart to the flake, not an overlap — see `docs/nix-darwin.md` for the division of labour.
- `.chezmoitemplates/shell-*.sh` hold the shared shell bodies rendered into the zsh and bash entry points; see `docs/shell-startup.md`.
- `bootstrap.sh` takes a fresh Mac to the point chezmoi can take over. Repo content, also in `.chezmoiignore`; see `docs/bootstrap.md`.
- `dot_zshenv.tmpl`, `dot_zshrc.tmpl`, `dot_bash_profile`, and `dot_bashrc.tmpl` are the shell entry points.
- Top-level docs like `README.md` and `AGENTS.md` describe usage and repository conventions.

## Branching
- Keep macOS configs on `main`. This repo targets macOS only.

## Build, Test, and Development Commands
- `chezmoi apply` applies the dotfiles using the configured source tree.
- `chezmoi apply --dry-run --refresh-externals=never` previews changes without updating pinned externals.
- `chezmoi execute-template --file <path>` renders a template for verification.

## Coding Style & Naming Conventions
- YAML uses 2-space indentation; keep list ordering stable in `.chezmoidata/*.yaml`.
- Keep config files in their chezmoi destination layout at the repo root (for example, `dot_config/starship.toml`).
- Environment files follow `<name>_environment.yml` (for example, `analysis_environment.yml`).

## Testing Guidelines
- There is no automated test suite in this repo.
- For changes that affect installation, run `chezmoi apply --dry-run --refresh-externals=never` and verify the rendered dotfiles.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries without prefixes (for example, `Update lazy.nvim config`, `Add mambarc`).
- PRs should include a brief summary, affected tools or paths, and how you verified changes (for example, `chezmoi apply --dry-run --refresh-externals=never`).
- Link related issues if applicable; add screenshots only for UI-facing config changes.

## Configuration & Security Notes
- Avoid committing secrets. Keep user-specific values in configs as placeholders.
- Place new configs at the repo root using chezmoi naming conventions so they render to the intended destination.
- Prefer plain files over templates. Only reach for `.tmpl` when a value genuinely varies or must be resolved at apply time.
- Keep `dot_config/nvim/lazy-lock.json` untracked; it is per-machine.
