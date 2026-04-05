# TODO

## Testing Plan

Use a layered testing approach for this `chezmoi` dotfiles repository.

### 1. Static checks

- Run `shellcheck` on shell scripts, `run_once_*`, `run_onchange_*`, and shell fragments under `dot_config/shell/`.
- Add syntax or format validation for app-specific config where practical, such as JSON, TOML, and Lua files.
- Wrap these in a single repo-local command so they are easy to run before committing.

### 2. Template rendering tests

- Test every `.tmpl` file by rendering it with `chezmoi execute-template --file`.
- Provide representative override data or prompt values for templates that branch on machine-specific inputs.
- Prioritize templates that affect executable scripts or host-specific configuration.

### 3. Integration test in a throwaway destination

- Run `chezmoi apply` against a temporary destination directory instead of the real home directory.
- Follow that with `chezmoi verify` against the same temporary destination.
- Treat this as the main end-to-end test because it catches broken templates, bad target paths, permissions issues, and idempotence problems.

Example:

```bash
tmpdir="$(mktemp -d)"
state="$(mktemp)"
chezmoi -S . -D "$tmpdir/home" --persistent-state "$state" apply --force
chezmoi -S . -D "$tmpdir/home" --persistent-state "$state" verify
```

### 4. Script behavior tests

- Add targeted tests only for scripts that contain real logic or side effects.
- Use a shell test harness such as `bats`, or plain shell tests if that is simpler.
- Stub external commands and run with temporary `HOME` and `PATH` values so tests stay deterministic.

### 5. Scope guidance

- Static config files should usually get linting or syntax validation only.
- Templates should always get render tests.
- Scripts with logic should get direct behavior tests.
- The repository as a whole should always have at least one temporary-destination `apply` plus `verify` test.
