# Profile Encryption

Encrypted files are split by profile so personal and work secrets use separate
age keys.

- Personal encrypted shell extras live under
  `dot_config/shell/personal/encrypted_90_extras.sh.age`.
- Work encrypted shell extras live under
  `dot_config/shell/work/encrypted_90_extras.sh.age`.
- Shell startup sources only `~/.config/shell/$SHELL_PROFILE/90_extras.sh`.
- If the active profile's age identity file is absent, that profile's optional
  encrypted shell extras are ignored instead of failing `chezmoi apply`.

The generated chezmoi config chooses the active profile from a known hostname,
or from `CHEZMOI_PROFILE` when explicitly set. Unknown hosts fail closed instead
of defaulting to personal.

Defaults:

- Personal identity: `~/.config/chezmoi/personal-key.txt`
- Work identity: `~/.config/chezmoi/work-key.txt`
- Personal recipient: the existing personal age recipient in `.chezmoi.toml.tmpl`
- Work recipient: committed in `.chezmoi.toml.tmpl` once the work key exists;
  until then, provide `CHEZMOI_WORK_AGE_RECIPIENT`

The age identity path in `.chezmoi.toml.tmpl` uses `~` because chezmoi accepts
that in its config. The ignore template checks the expanded path under
`.chezmoi.homeDir`, so the optional encrypted extras are skipped when the
matching key file is not present.

## Key Bootstrap

Use `scripts/bootstrap-age-key` from a clone of this repo before the first
`chezmoi init --apply` on a machine. It installs only the active profile's
private age identity and keeps personal/work keys in separate files.
Do not install the inactive profile's key on hosts where that profile should
not be decryptable.

On known hosts, the helper refuses to install a key for the wrong profile. Set
`CHEZMOI_ALLOW_AGE_PROFILE_MISMATCH=1` only when deliberately overriding that
guard during migration.

Import the existing personal key on personal machines:

```bash
scripts/bootstrap-age-key personal /path/to/personal-key.txt
```

On work machines, either import an existing work key or generate the first work
key. Do not reuse the personal key for work.

```bash
scripts/bootstrap-age-key work /path/to/work-key.txt
scripts/bootstrap-age-key --generate work
```

When `age-keygen` is installed, the helper prints the public recipient for the
installed key. Use that work recipient when initializing or regenerating chezmoi
config until the work recipient has been committed:

```bash
CHEZMOI_PROFILE=work \
CHEZMOI_WORK_AGE_RECIPIENT=age1... \
chezmoi init --apply <repo>
```

After the first work key exists, commit its public recipient as
`$workAgeRecipientDefault` in `.chezmoi.toml.tmpl`. That value is public; the
private key remains only in `~/.config/chezmoi/work-key.txt` on work hosts.

For personal hosts, the built-in personal recipient is already the default. If
the personal key's recipient ever changes, set `CHEZMOI_PERSONAL_AGE_RECIPIENT`
while regenerating chezmoi config and re-encrypt the personal files.

For a new personal host that is not yet listed in `.chezmoi.toml.tmpl` and
`.chezmoidata/hosts.yaml`, set `CHEZMOI_PROFILE=personal` explicitly during
initialization.

Optional overrides:

- `CHEZMOI_PERSONAL_AGE_IDENTITY`
- `CHEZMOI_PERSONAL_AGE_RECIPIENT`
- `CHEZMOI_WORK_AGE_IDENTITY`
- `CHEZMOI_WORK_AGE_RECIPIENT`
