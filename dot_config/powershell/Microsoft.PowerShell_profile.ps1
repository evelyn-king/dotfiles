# Use the chezmoi-managed configs while keeping native Windows data/cache paths.
$env:XDG_CONFIG_HOME = Join-Path $HOME '.config'
$env:MISE_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'mise'
$env:STARSHIP_CONFIG = Join-Path $env:XDG_CONFIG_HOME 'starship.toml'
$env:ATUIN_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'atuin'
$env:EDITOR = 'nvim'
# ANSI colours, so bat follows the terminal scheme `theme` sets. It
# overrides the Gruvbox choice in ~/.config/bat/config.
$env:BAT_THEME = 'ansi'
$env:VISUAL = $env:EDITOR

# Check at startup so a partial bootstrap still leaves a usable shell.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    # Windows PowerShell refreshes mise at the prompt instead of on cd.
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $env:MISE_PWSH_CHPWD_WARNING = '0'
    }
    mise activate pwsh | Out-String | Invoke-Expression
}

# --- aliases and functions --------------------------------------------------

# Ported from .chezmoitemplates/shell-interactive.sh. PowerShell aliases cannot
# carry arguments, so anything beyond a plain rename is a function that
# forwards @args. Tool checks run after `mise activate` so mise tools count.
function Test-DotfilesCommand([string]$Name) {
    [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

# Omarchy-style theme switching; see docs/windows-themes.md.
function theme { & (Join-Path $HOME '.config/omarchy-windows/theme.ps1') @args }

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

# `n` with no argument opens the current directory rather than an empty buffer.
function n {
    if ($args.Count -eq 0) { nvim . } else { nvim @args }
}

# The built-in ls (Get-ChildItem) stays, so listings remain pipeable objects.
# -Force adds the hidden and system entries, like `ls -a`.
function lsa { Get-ChildItem -Force @args }

if (Test-DotfilesCommand eza) {
    function lt { eza --tree --level=2 --long --icons --git @args }
    function lta { lt -a @args }
}

if ((Test-DotfilesCommand fzf) -and (Test-DotfilesCommand bat)) {
    function ff { fzf --preview 'bat --style=numbers --color=always {}' @args }
    function eff {
        $file = ff
        if ($file) { & $env:EDITOR $file }
    }
}

if (Test-DotfilesCommand bun) { function bunx { bun x @args } }
if (Test-DotfilesCommand opencode) { function c { opencode --auto @args } }
if (Test-DotfilesCommand codex) { function cy { codex --approve-for-me @args } }

# Clear scrollback as well as the screen before handing the terminal over.
# [char]27 rather than `e, which Windows PowerShell 5.1 does not understand.
if (Test-DotfilesCommand claude) {
    function cx {
        $esc = [char]27
        [Console]::Write("$esc[2J$esc[3J$esc[H")
        claude --permission-mode auto @args
    }
}

# Refresh the shared mise lock for every platform, then install what it holds
# for this machine. Mirrors `mup` in .chezmoitemplates/shell-interactive.sh;
# keep the platform lists in step. The lock lives only in the source tree, which
# `chezmoi source-path` finds at run time so this file needs no templating.
if ((Test-DotfilesCommand mise) -and (Test-DotfilesCommand chezmoi)) {
    function mup {
        $sourceDir = chezmoi source-path
        if ($LASTEXITCODE -ne 0 -or -not $sourceDir) { return }

        $previous = $env:MISE_CONFIG_DIR
        $env:MISE_CONFIG_DIR = Join-Path $sourceDir 'dot_config/mise'
        try {
            mise --cd / lock --global --platform linux-x64 --platform macos-arm64 --platform windows-x64 --bump
            if ($LASTEXITCODE -ne 0) { return }
            mise --cd / bootstrap --only tools --locked
        }
        finally {
            $env:MISE_CONFIG_DIR = $previous
        }
    }
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
