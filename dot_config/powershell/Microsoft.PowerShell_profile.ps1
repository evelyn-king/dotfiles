# Use the chezmoi-managed configs while keeping native Windows data/cache paths.
$env:XDG_CONFIG_HOME = Join-Path $HOME '.config'
$env:MISE_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'mise'
$env:STARSHIP_CONFIG = Join-Path $env:XDG_CONFIG_HOME 'starship.toml'
$env:ATUIN_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'atuin'
$env:EDITOR = 'nvim'
$env:VISUAL = $env:EDITOR

# Check at startup so a partial bootstrap still leaves a usable shell.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    # Windows PowerShell refreshes mise at the prompt instead of on cd.
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $env:MISE_PWSH_CHPWD_WARNING = '0'
    }
    mise activate pwsh | Out-String | Invoke-Expression
}

# Install the prompt before hooks that wrap it (such as zoxide).
if (Get-Command starship -ErrorAction SilentlyContinue) {
    starship init powershell | Out-String | Invoke-Expression
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init --cmd cd powershell | Out-String | Invoke-Expression
}

# Atuin uses PSReadLine for history capture and Ctrl-R / UpArrow search.
if (Get-Command atuin -ErrorAction SilentlyContinue) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    if ((Get-Module PSReadLine) -and -not (Get-Module Atuin)) {
        atuin init powershell | Out-String | Invoke-Expression
    }
}
