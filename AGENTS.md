# Repository Guidelines

## Project Structure & Module Organization
- `.chezmoi.toml.tmpl` bootstraps chezmoi and selects the repo root as `sourceDir`.
- The repo root is the chezmoi source state for files under `$HOME`.
- `.chezmoidata/` carries template data.
- Top-level docs like `README.md` and `AGENTS.md` describe usage and repository conventions.

## Branching
- Keep macOS/Linux configs on `main`.
- Use the separate `windows` branch for native Windows history.

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
- On `main`, place new configs at the repo root using chezmoi naming conventions so they render to the intended destination.
- Put native Windows changes on the `windows` branch.
- Keep `dot_config/nvim/lazy-lock.json` untracked; it is per-machine.
