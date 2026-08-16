# Encryption

Encrypted files use a single age key.

- Encrypted shell extras live at `dot_config/shell/encrypted_extras.sh.age` and
  render to `~/.config/shell/extras.sh`, which `~/.zshrc` sources if present.
- If the age identity file is absent, the encrypted extras are ignored rather
  than failing `chezmoi apply`.

Defaults:

- Identity: `~/.config/chezmoi/key.txt`
- Recipient: committed in `.chezmoi.toml.tmpl` (a public age recipient is not a
  secret)

The identity path in `.chezmoi.toml.tmpl` uses `~` because chezmoi accepts that
in its config. `.chezmoiignore.tmpl` checks the expanded path under
`.chezmoi.homeDir`, so the optional encrypted extras are skipped when the key
file is not present.

## Key Bootstrap

Use `scripts/bootstrap-age-key` from a clone of this repo before the first
`chezmoi init --apply` on a machine.

Import an existing key:

```bash
scripts/bootstrap-age-key /path/to/key.txt
```

Or generate a new one:

```bash
scripts/bootstrap-age-key --generate
```

The key can also be piped in on stdin. When `age-keygen` is installed, the
helper prints the public recipient for the installed key.

If the key's recipient ever changes, set `CHEZMOI_AGE_RECIPIENT` while
regenerating chezmoi config and re-encrypt the affected files.

Optional overrides:

- `CHEZMOI_AGE_IDENTITY`
- `CHEZMOI_AGE_RECIPIENT`
