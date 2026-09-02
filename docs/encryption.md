# Encryption

A single age key encrypts everything in this repo that needs it. There is one
encrypted file today:

- `dot_config/shell/encrypted_private_secrets.sh.age`, applied to
  `~/.config/shell/secrets.sh` and sourced near the end of interactive shell
  startup.

When the age identity file is absent, chezmoi skips that file instead of
failing the apply. `.chezmoiignore.tmpl` checks for the identity with `stat` and
ignores the target when it is missing, so a fresh machine can apply before the
key is in place.

## Paths

- Identity (private, never committed): `~/.config/chezmoi/personal-key.txt`
- Recipient (public, committed in `.chezmoi.toml.tmpl`)

Two environment variables override them, which is what lets you roll a key
without editing the template first:

- `CHEZMOI_AGE_IDENTITY`
- `CHEZMOI_AGE_RECIPIENT`

The identity path in `.chezmoi.toml.tmpl` uses `~` because chezmoi accepts that
in its own config. `.chezmoiignore.tmpl` expands it against `.chezmoi.homeDir`
instead, since template functions do not expand `~`.

## Key bootstrap

Run `scripts/bootstrap-age-key` from a clone of this repo before the first
`chezmoi init --apply` on a machine.

Import an existing key:

```bash
scripts/bootstrap-age-key /path/to/personal-key.txt
```

Or generate a new one:

```bash
scripts/bootstrap-age-key --generate
```

The helper refuses to overwrite an existing identity, checks that the input
looks like an age identity before installing it, and writes the file 0600. When
`age-keygen` is available it prints the public recipient afterwards.

## Rolling the key

1. Generate the new identity somewhere safe.
2. Decrypt the existing encrypted files with the old key.
3. Commit the new public recipient to `.chezmoi.toml.tmpl`.
4. Re-encrypt with `chezmoi re-add` (or `chezmoi add --encrypt`) once the new
   recipient is the configured one.
5. Run `chezmoi init` on each machine so the regenerated config picks up the
   new recipient.
