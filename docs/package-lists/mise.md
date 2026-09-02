# mise tool list

mise installs the same language runtimes and user-level CLI tools on macOS and
Linux. Their declarations live in
[`dot_config/mise/conf.d/10-dotfiles.toml`](../../dot_config/mise/conf.d/10-dotfiles.toml).

The TOML file is the source of truth for requested versions. Most tools have
exact pins. Coding agents, `gh`, and `usage` track `latest` by design, while
Rust tracks the stable release channel. On Linux,
[`dot_config/mise/mise.lock`](../../dot_config/mise/mise.lock) resolves them to
reviewable versions and checksums for `linux-x64` where the backend exposes a
fixed artifact. The Rust entry remains `stable`; rustup resolves that channel
when mise installs or updates it.

## Shared tools

These tools install on both macOS and Linux.

| Declaration | Command | Purpose |
| --- | --- | --- |
| `node` | `node`, `npm`, `npx` | Node.js runtime and package tooling |
| `python` | `python`, `pip` | Python runtime and package tooling |
| `go` | `go` | Go compiler and toolchain |
| `rust` | `rustup`, `rustc`, `cargo`, `rustfmt`, `cargo-clippy` | Rust stable toolchain, installed through rustup by mise |
| `claude` | `claude` | Claude Code coding agent |
| `codex` | `codex` | OpenAI Codex coding agent |
| `opencode` | `opencode` | opencode coding agent |
| `pi` | `pi` | Pi coding agent |
| `npm:@google/gemini-cli` | `gemini` | Gemini coding agent |
| `npm:@just-every/code` | `code` | Just Every Code coding agent |
| `pipx:black` | `black` | Python code formatter |
| `pipx:conda-lock` | `conda-lock` | Reproducible lockfiles for conda environments |
| `pipx:conda-package-handling` | `cph` | Inspect, create, and convert conda packages |
| `pipx:docling-slim` | `docling` | Convert documents to Markdown and other structured formats |
| `pipx:markdown-code-runner` | `markdown-code-runner` | Execute Markdown code blocks and update their recorded output |
| `pipx:mypy` | `mypy` | Static type checker for Python |
| `pipx:poethepoet` | `poe` | Project task runner |
| `pipx:pre-commit` | `pre-commit` | Run repository hooks before commits |
| `pipx:ruff` | `ruff` | Python linter and formatter |
| `pipx:tuitorial` | `tuitorial` | Present code tutorials in a terminal UI |
| `pipx:unidep` | `unidep` | Keep conda and pip dependency declarations in sync |
| `npm:@doist/todoist-cli` | `td` | Manage Todoist from the command line |
| `npm:@googleworkspace/cli` | `gws` | Work with Google Workspace APIs |
| `npm:tree-sitter-cli` | `tree-sitter` | Generate and test Tree-sitter parsers |
| `gh` | `gh` | GitHub CLI |
| `herdr` | `herdr` | Persistent terminal sessions and orchestration for coding agents |
| `usage` | `usage` | Generate shell completions and usage specifications for CLIs |
| `micromamba` | `micromamba` | Lightweight conda-compatible environment manager |

`unidep` installs with its `all` extra, and `pre-commit` installs with
`pre-commit-uv`. Those additions are recorded as `uvx_args` in the shared
configuration.

## Installation and updates

`run_onchange_after_mise-install.sh.tmpl` runs the install after the
configuration file changes. Apply a declaration change with:

```bash
chezmoi apply
```

Run `mup` to update floating tools and their lock resolution. On Linux, review
and commit the resulting `dot_config/mise/mise.lock` change. Update mise itself
separately with `mise self-update`.
