# Omarchy-style theme switching for native Windows.
#
#   theme list | current | set <name> | refresh | bg next | install <git-url> | remove <name>
#
# set, refresh and install return once the theme is staged; Windows mode,
# accent, wallpaper and VS Code are applied by a hidden background process,
# since broadcasting a setting change waits on every open window. -Wait applies
# them before returning instead. Background failures go to
# ~/.local/state/omarchy/theme-apply.log.
#
# A PowerShell port of Omarchy's omarchy-theme-* commands. Themes use Omarchy's
# own format, so a theme works unchanged on both systems:
#
#   ~/.local/share/omarchy/themes/<name>/   stock themes (chezmoi external, pinned)
#   ~/.config/omarchy/themes/<name>/        your themes, overlaid on a stock one
#   ~/.config/omarchy/themed/*.tpl          your templates, ahead of the ones below
#   ~/.config/omarchy/backgrounds/<name>/   extra wallpapers for a theme
#   ~/.config/omarchy/hooks/theme-set.d/    *.ps1 run after a switch, theme in $args[0]
#   ~/.local/state/omarchy/current/theme/   the staged, rendered current theme
#
# Toggle files in ~/.local/state/omarchy/toggles/ opt out of individual
# targets: skip-windows-mode, skip-windows-accent, skip-windows-wallpaper,
# skip-vscode-theme-changes.
#
# Runs under Windows PowerShell 5.1 and PowerShell 7 alike.

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'current',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @(),
    # With refresh: the theme to set when none is set yet, as on a fresh machine.
    [string]$IfUnset,
    # Apply the Windows targets before returning rather than in the background.
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:OnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Get-Variable IsWindows -ValueOnly -ErrorAction SilentlyContinue) -eq $true)

function Join-Parts([string]$Base) {
    $path = $Base
    foreach ($part in $args) { $path = Join-Path $path $part }
    $path
}

$OmarchyPath = if ($env:OMARCHY_PATH) { $env:OMARCHY_PATH } else { Join-Parts $HOME '.local' 'share' 'omarchy' }
$StockThemes = Join-Path $OmarchyPath 'themes'
$StockTemplates = Join-Parts $OmarchyPath 'default' 'themed'
$UserConfig = Join-Parts $HOME '.config' 'omarchy'
$UserThemes = Join-Path $UserConfig 'themes'
$UserTemplates = Join-Path $UserConfig 'themed'
$UserBackgrounds = Join-Path $UserConfig 'backgrounds'
$HookDir = Join-Parts $UserConfig 'hooks' 'theme-set.d'
$EngineTemplates = Join-Path $PSScriptRoot 'themed'
$StateDir = Join-Parts $HOME '.local' 'state' 'omarchy'
$CurrentDir = Join-Path $StateDir 'current'
$CurrentTheme = Join-Path $CurrentDir 'theme'
$NextTheme = Join-Path $CurrentDir 'next-theme'
$CurrentName = Join-Path $CurrentDir 'theme.name'
$CurrentBackground = Join-Path $CurrentDir 'background'
$BackgroundMemory = Join-Path $StateDir 'theme-backgrounds'
$ToggleDir = Join-Path $StateDir 'toggles'
$ApplyLog = Join-Path $StateDir 'theme-apply.log'
$BackgroundCache = Join-Parts $HOME '.cache' 'omarchy' 'backgrounds'

# Of Omarchy's own templates only these have a consumer on Windows. The rest
# (Hyprland, Waybar, terminals that don't exist here) would render unused.
$StockTemplateAllowList = @('neovim.lua.tpl', 'btop.theme.tpl')

# What a theme cloned from a git repo may not ship, as in omarchy-theme-set:
# Neovim runs a theme's neovim.lua, and vscode.json names an extension to
# install, so both are code rather than colour.
$InstalledThemeDenied = @('alacritty.toml', 'foot.ini', 'ghostty.conf', 'kitty.conf', 'vscode.json')

$BackgroundExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.webp', '.gif')
$Utf8 = New-Object System.Text.UTF8Encoding $false

# --- helpers ------------------------------------------------------------------

function Write-Utf8([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Read-Text([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { ([IO.File]::ReadAllText($Path)).Trim() } else { '' }
}

function Test-Toggle([string]$Name) {
    Test-Path -LiteralPath (Join-Path $ToggleDir $Name)
}

function ConvertTo-ThemeSlug([string]$Name) {
    (($Name -replace '<[^>]+>', '').Trim().ToLowerInvariant()) -replace ' ', '-'
}

function Test-ThemeSlug([string]$Slug) {
    $Slug -cmatch '^[a-z0-9_][a-z0-9._+-]*$'
}

function ConvertTo-DisplayName([string]$Slug) {
    (($Slug -split '-') | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) } else { $_ }
        }) -join ' '
}

function Get-ThemeSources([string]$Slug) {
    @((Join-Path $StockThemes $Slug), (Join-Path $UserThemes $Slug)) |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container }
}

function Test-FromRepo([string]$Dir) {
    $item = Get-Item -LiteralPath $Dir -Force
    (-not $item.LinkType) -and (Test-Path -LiteralPath (Join-Path $Dir '.git'))
}

# --- colors.toml ----------------------------------------------------------------

function ConvertFrom-Hex([string]$Hex) {
    $h = $Hex.TrimStart('#')
    @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}

function Test-Hex([string]$Value) { $Value -match '^#[0-9A-Fa-f]{6}$' }

# Mix two hex colours; Amount is a fraction or a percentage, as in Omarchy.
function Get-MixColor([string]$Start, [string]$End, [string]$Amount) {
    if ($Amount.EndsWith('%')) { $a = [double]$Amount.TrimEnd('%') / 100 }
    else { $a = [double]$Amount; if ($a -gt 1) { $a = $a / 100 } }
    $a = [Math]::Min(1.0, [Math]::Max(0.0, $a))
    $s = ConvertFrom-Hex $Start
    $e = ConvertFrom-Hex $End
    $out = for ($i = 0; $i -lt 3; $i++) { [int][Math]::Floor($s[$i] * (1 - $a) + $e[$i] * $a + 0.5) }
    '#{0:x2}{1:x2}{2:x2}' -f $out[0], $out[1], $out[2]
}

function Read-ColorsToml([string]$Path) {
    $colors = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { continue }
        $key = ($line.Substring(0, $idx) -replace '["'' ]', '')
        if (-not $key -or $key.StartsWith('#')) { continue }
        $value = $line.Substring($idx + 1)
        if ($value -match '["'']([^"'']*)["'']') { $value = $Matches[1] } else { $value = $value.Trim() }
        if ($key -notmatch '^[A-Za-z0-9_-]+$') { continue }
        if ($value -notmatch '^[A-Za-z0-9#(),._+/% -]*$') {
            Write-Warning "theme: skipping $key, unsupported characters in value"
            continue
        }
        $colors[$key] = $value
    }
    $colors
}

# The alias and fallback cascade of omarchy-theme-color, so templates see the
# same palette they do on Omarchy.
function Resolve-ThemeColors([hashtable]$c, [string]$ThemeDir) {
    function Has($k) { $c.ContainsKey($k) -and [string]$c[$k] }
    function Alias($k, $from) { if (-not (Has $k)) { $c[$k] = if ($c.ContainsKey($from)) { $c[$from] } else { '' } } }

    $legacyPalette = [ordered]@{
        background = 'bg'; dark_background = 'dark_bg'; darker_background = 'darker_bg'; lighter_background = 'lighter_bg'
        foreground = 'fg'; dark_foreground = 'dark_fg'; light_foreground = 'light_fg'; bright_foreground = 'bright_fg'
    }
    foreach ($k in $legacyPalette.Keys) { Alias $k $legacyPalette[$k] }

    if (-not (Has 'background')) { Alias 'background' 'color0' }
    if (-not (Has 'foreground')) { Alias 'foreground' 'color7' }
    if (Has 'background') { $c['color0'] = $c['background'] }
    if (Has 'foreground') { $c['color7'] = $c['foreground'] }

    $legacy = [ordered]@{
        red = 'color1'; green = 'color2'; yellow = 'color3'; blue = 'color4'; magenta = 'color5'; cyan = 'color6'
        bright_red = 'color9'; bright_green = 'color10'; bright_yellow = 'color11'; bright_blue = 'color12'
        bright_magenta = 'color13'; bright_cyan = 'color14'
    }
    foreach ($k in $legacy.Keys) { Alias $k $legacy[$k] }
    Alias 'magenta' 'purple'
    Alias 'bright_magenta' 'bright_purple'

    function First { foreach ($k in $args) { if (Has $k) { return $c[$k] } }; '' }
    if (-not (Has 'light_foreground')) { $c['light_foreground'] = First 'color7' 'foreground' }
    if (-not (Has 'bright_foreground')) { $c['bright_foreground'] = First 'color15' 'foreground' }
    $c['cursor'] = $c['bright_foreground']
    if (-not (Has 'lighter_background')) { $c['lighter_background'] = First 'color0' 'background' }
    if (-not (Has 'dark_foreground')) { $c['dark_foreground'] = First 'color8' 'foreground' }
    if (-not (Has 'muted')) { $c['muted'] = First 'color8' 'dark_foreground' }
    if (-not (Has 'selection')) { $c['selection'] = First 'selection_background' 'color8' 'color0' 'background' }
    if (-not (Has 'selection_background')) { $c['selection_background'] = $c['selection'] }
    if (-not (Has 'selection_foreground')) { $c['selection_foreground'] = $c['bright_foreground'] }
    if (-not (Has 'orange')) { $c['orange'] = $c['yellow'] }
    if (-not (Has 'brown') -and (Test-Hex $c['orange'])) { $c['brown'] = Get-MixColor $c['orange'] '#000000' '50%' }

    if (Test-Hex $c['background']) {
        if (-not (Has 'dark_background')) { $c['dark_background'] = Get-MixColor $c['background'] '#000000' '25%' }
        if (-not (Has 'darker_background')) { $c['darker_background'] = Get-MixColor $c['background'] '#000000' '50%' }
    }
    foreach ($base in 'red', 'yellow', 'green', 'cyan', 'blue', 'magenta') {
        if (-not (Has "bright_$base") -and (Test-Hex $c[$base])) { $c["bright_$base"] = Get-MixColor $c[$base] '#ffffff' '20%' }
    }
    Alias 'purple' 'magenta'
    Alias 'bright_purple' 'bright_magenta'

    $ansi = [ordered]@{
        color0 = 'background'; color1 = 'red'; color2 = 'green'; color3 = 'yellow'; color4 = 'blue'; color5 = 'magenta'
        color6 = 'cyan'; color7 = 'foreground'; color8 = 'muted'; color9 = 'bright_red'; color10 = 'bright_green'
        color11 = 'bright_yellow'; color12 = 'bright_blue'; color13 = 'bright_magenta'; color14 = 'bright_cyan'
        color15 = 'bright_foreground'
    }
    foreach ($k in $ansi.Keys) { Alias $k $ansi[$k] }
    foreach ($k in $legacyPalette.Keys) { if (Has $k) { $c[$legacyPalette[$k]] = $c[$k] } }

    if (-not (Has 'mode')) { Alias 'mode' 'theme_type' }
    if (-not (Has 'mode')) {
        if (Test-Path -LiteralPath (Join-Path $ThemeDir 'light.mode')) { $c['mode'] = 'light' }
        elseif (Test-Hex $c['background']) {
            $rgb = ConvertFrom-Hex $c['background']
            $c['mode'] = if (($rgb[0] + $rgb[1] + $rgb[2]) -gt 382) { 'light' } else { 'dark' }
        }
        else { $c['mode'] = 'dark' }
    }
    $c['theme_type'] = $c['mode']
    if (-not (Has 'accent')) { $c['accent'] = $c['blue'] }
    $c
}

# --- templates ------------------------------------------------------------------

# {{ key }}, {{ key_strip }}, {{ key_rgb }} and {{ mix[_strip|_rgb] a b N% }}.
# Anything else is left in place, as Omarchy's sed pass does.
function Expand-ThemeTemplate([string]$Text, [hashtable]$Colors) {
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $token = $m.Groups[1].Value.Trim()
        $parts = $token -split '\s+'
        if ($parts.Count -eq 4 -and $parts[0] -match '^mix(_strip|_rgb)?$') {
            $a = $Colors[$parts[1]]; $b = $Colors[$parts[2]]
            if (-not ((Test-Hex $a) -and (Test-Hex $b))) { return $m.Value }
            $value = Get-MixColor $a $b $parts[3]
            switch ($parts[0]) {
                'mix_strip' { return $value.TrimStart('#') }
                'mix_rgb' { return ((ConvertFrom-Hex $value) -join ',') }
                default { return $value }
            }
        }
        if ($parts.Count -ne 1) { return $m.Value }
        if ($Colors.ContainsKey($token)) { return [string]$Colors[$token] }
        if ($token -match '^(.+)_strip$' -and $Colors.ContainsKey($Matches[1])) { return ([string]$Colors[$Matches[1]]).TrimStart('#') }
        if ($token -match '^(.+)_rgb$' -and $Colors.ContainsKey($Matches[1]) -and (Test-Hex $Colors[$Matches[1]])) {
            return ((ConvertFrom-Hex $Colors[$Matches[1]]) -join ',')
        }
        $m.Value
    }
    [regex]::Replace($Text, '\{\{([^{}]+)\}\}', $evaluator)
}

function Get-TemplateFiles {
    $files = @()
    foreach ($dir in @($UserTemplates, $EngineTemplates)) {
        if (Test-Path -LiteralPath $dir) { $files += @(Get-ChildItem -LiteralPath $dir -Filter '*.tpl' -File | Sort-Object Name) }
    }
    if (Test-Path -LiteralPath $StockTemplates) {
        $files += @(Get-ChildItem -LiteralPath $StockTemplates -Filter '*.tpl' -File |
                Where-Object { $StockTemplateAllowList -contains $_.Name } | Sort-Object Name)
    }
    $files
}

# --- staging ----------------------------------------------------------------------

# Backgrounds and previews stay where they are: wallpapers are read from the
# source directories, so a switch doesn't copy megabytes of images around.
function Copy-ThemeDir([string]$Source, [string]$Dest, [bool]$Untrusted) {
    foreach ($entry in Get-ChildItem -LiteralPath $Source -Force) {
        if ($entry.Name -eq '.git' -or $entry.Name -eq 'backgrounds' -or $entry.Name -like 'preview*.png' -or $entry.Name -eq 'unlock.png') { continue }
        if ($Untrusted) {
            if ($entry.LinkType -or $entry.Name -like '*.lua' -or $InstalledThemeDenied -contains $entry.Name) {
                if ($entry.Name -notmatch '^(readme|license|changelog)|\.(md|txt)$') {
                    Write-Warning "theme: ignored $($entry.Name); a theme installed from a git repo cannot supply Lua, a terminal config, or vscode.json."
                }
                continue
            }
        }
        $target = Join-Path $Dest $entry.Name
        if ($entry.PSIsContainer) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Copy-ThemeDir $entry.FullName $target $Untrusted
        }
        else {
            Copy-Item -LiteralPath $entry.FullName -Destination $target -Force
        }
    }
}

function New-StagedTheme([string]$Slug) {
    if (Test-Path -LiteralPath $NextTheme) { Remove-Item -LiteralPath $NextTheme -Recurse -Force }
    New-Item -ItemType Directory -Path $NextTheme -Force | Out-Null

    $stock = Join-Path $StockThemes $Slug
    if (Test-Path -LiteralPath $stock) { Copy-ThemeDir $stock $NextTheme $false }
    $user = Join-Path $UserThemes $Slug
    if (Test-Path -LiteralPath $user) { Copy-ThemeDir $user $NextTheme (Test-FromRepo $user) }

    $colorsFile = Join-Path $NextTheme 'colors.toml'
    if (-not (Test-Path -LiteralPath $colorsFile)) {
        throw "Theme '$Slug' has no colors.toml. Themes that predate it are not supported on Windows."
    }
    $colors = Resolve-ThemeColors (Read-ColorsToml $colorsFile) $NextTheme

    # A file the theme ships wins over any template, then yours, then the
    # engine's, then Omarchy's.
    foreach ($tpl in Get-TemplateFiles) {
        $out = Join-Path $NextTheme ([IO.Path]::GetFileNameWithoutExtension($tpl.Name))
        if (Test-Path -LiteralPath $out) { continue }
        Write-Utf8 $out (Expand-ThemeTemplate ([IO.File]::ReadAllText($tpl.FullName)) $colors)
    }

    if (Test-Path -LiteralPath $CurrentTheme) { Remove-Item -LiteralPath $CurrentTheme -Recurse -Force }
    Move-Item -LiteralPath $NextTheme -Destination $CurrentTheme
    Write-Utf8 $CurrentName "$Slug`n"
    $colors
}

# --- backgrounds --------------------------------------------------------------------

function Get-ThemeBackgrounds([string]$Slug) {
    $dirs = @((Join-Path $UserBackgrounds $Slug))
    foreach ($src in Get-ThemeSources $Slug) { $dirs += (Join-Path $src 'backgrounds') }
    $files = foreach ($dir in $dirs) {
        if (Test-Path -LiteralPath $dir) {
            Get-ChildItem -LiteralPath $dir -File | Where-Object { $BackgroundExtensions -contains $_.Extension.ToLowerInvariant() }
        }
    }
    @($files | Sort-Object FullName | ForEach-Object { $_.FullName })
}

function Select-ThemeBackground([string]$Slug, [string]$Previous, [bool]$Advance) {
    $all = @(Get-ThemeBackgrounds $Slug)
    if ($all.Count -eq 0) { return $null }
    $current = Read-Text $CurrentBackground
    if ($Previous -eq $Slug) {
        $index = [array]::IndexOf($all, $current)
        if ($index -lt 0) { return $all[0] }
        if ($Advance) { return $all[($index + 1) % $all.Count] }
        return $current
    }
    $remembered = Read-Text (Join-Path $BackgroundMemory $Slug)
    if ($remembered -and ($all -contains $remembered)) { return $remembered }
    $all[0]
}

# Windows can't always decode WebP for a wallpaper, and most Omarchy
# backgrounds are WebP, so convert through WIC into a cached JPEG. A failed
# conversion falls back to handing Windows the original.
function ConvertTo-WallpaperFile([string]$Path) {
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -ne '.webp') { return $Path }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.Substring(0, 12)
    $out = Join-Path $BackgroundCache ("{0}-{1}.jpg" -f [IO.Path]::GetFileNameWithoutExtension($Path), $hash)
    if (Test-Path -LiteralPath $out) { return $out }
    try {
        Add-Type -AssemblyName PresentationCore
        New-Item -ItemType Directory -Path $BackgroundCache -Force | Out-Null
        $decoder = [Windows.Media.Imaging.BitmapDecoder]::Create([Uri]$Path, [Windows.Media.Imaging.BitmapCreateOptions]::None, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $encoder = New-Object Windows.Media.Imaging.JpegBitmapEncoder
        $encoder.QualityLevel = 95
        $encoder.Frames.Add($decoder.Frames[0])
        $stream = [IO.File]::Create($out)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
        $out
    }
    catch {
        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
        $Path
    }
}

# --- Windows ----------------------------------------------------------------------

function Initialize-Win32 {
    if ('OmarchyTheme.Win32' -as [type]) { return }
    Add-Type -Namespace OmarchyTheme -Name Win32 -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@
}

function Send-SettingChange([string]$Area) {
    Initialize-Win32
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST, WM_SETTINGCHANGE, SMTO_ABORTIFHUNG
    [void][OmarchyTheme.Win32]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, $Area, 2, 3000, [ref]$result)
}

function Set-RegistryValue([string]$Key, [string]$Name, $Value, [string]$Type) {
    if (-not (Test-Path -LiteralPath $Key)) { New-Item -Path $Key -Force | Out-Null }
    New-ItemProperty -LiteralPath $Key -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# Registry DWORDs are signed to PowerShell; reinterpret the unsigned value.
function ConvertTo-DWord([int64]$Value) {
    [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$Value), 0)
}

function ConvertTo-Abgr([string]$Hex) {
    $rgb = ConvertFrom-Hex $Hex
    ConvertTo-DWord (4278190080 + $rgb[2] * 65536 + $rgb[1] * 256 + $rgb[0])
}

function Set-WindowsMode([string]$Mode) {
    $light = if ($Mode -eq 'light') { 1 } else { 0 }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-RegistryValue $key 'AppsUseLightTheme' $light 'DWord'
    Set-RegistryValue $key 'SystemUsesLightTheme' $light 'DWord'
}

# Accent colour for the title bars, Start and the taskbar. The palette runs
# from lightest to darkest around the accent, the layout Settings writes.
function Set-WindowsAccent([string]$Accent) {
    if (-not (Test-Hex $Accent)) { return }
    $shades = @(
        (Get-MixColor $Accent '#ffffff' '60%'), (Get-MixColor $Accent '#ffffff' '40%'), (Get-MixColor $Accent '#ffffff' '20%'),
        $Accent,
        (Get-MixColor $Accent '#000000' '20%'), (Get-MixColor $Accent '#000000' '40%'), (Get-MixColor $Accent '#000000' '60%'),
        (Get-MixColor $Accent '#000000' '75%')
    )
    $palette = New-Object byte[] 32
    for ($i = 0; $i -lt 8; $i++) {
        $rgb = ConvertFrom-Hex $shades[$i]
        $palette[$i * 4] = $rgb[0]; $palette[$i * 4 + 1] = $rgb[1]; $palette[$i * 4 + 2] = $rgb[2]; $palette[$i * 4 + 3] = 0
    }
    $rgb = ConvertFrom-Hex $Accent
    $argb = ConvertTo-DWord (3288334336 + $rgb[0] * 65536 + $rgb[1] * 256 + $rgb[2])

    Set-RegistryValue 'HKCU:\Control Panel\Desktop' 'AutoColorization' '0' 'String'
    $explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    Set-RegistryValue $explorer 'AccentPalette' $palette 'Binary'
    Set-RegistryValue $explorer 'AccentColorMenu' (ConvertTo-Abgr $Accent) 'DWord'
    Set-RegistryValue $explorer 'StartColorMenu' (ConvertTo-Abgr $shades[5]) 'DWord'
    $dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
    Set-RegistryValue $dwm 'AccentColor' (ConvertTo-Abgr $Accent) 'DWord'
    Set-RegistryValue $dwm 'ColorizationColor' $argb 'DWord'
    Set-RegistryValue $dwm 'ColorizationAfterglow' $argb 'DWord'
}

function Set-Wallpaper([string]$Path) {
    Initialize-Win32
    Set-RegistryValue 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10' 'String'  # fill
    Set-RegistryValue 'HKCU:\Control Panel\Desktop' 'TileWallpaper' '0' 'String'
    # SPI_SETDESKWALLPAPER, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
    if (-not [OmarchyTheme.Win32]::SystemParametersInfo(0x14, 0, $Path, 3)) {
        Write-Warning "theme: Windows refused the wallpaper $Path"
    }
}

# Windows Terminal loads colour schemes from JSON fragments, which it never
# writes back to, unlike its settings.json. Touching settings.json afterwards
# makes a running Terminal reload, which re-reads the fragments too.
function Update-WindowsTerminal {
    $rendered = Join-Path $CurrentTheme 'windows-terminal.json'
    if (-not (Test-Path -LiteralPath $rendered) -or -not $env:LOCALAPPDATA) { return }
    $fragment = Join-Parts $env:LOCALAPPDATA 'Microsoft' 'Windows Terminal' 'Fragments' 'Omarchy' 'theme.json'
    Write-Utf8 $fragment ([IO.File]::ReadAllText($rendered))
    foreach ($package in @('Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe')) {
        $settings = Join-Parts $env:LOCALAPPDATA 'Packages' $package 'LocalState' 'settings.json'
        if (Test-Path -LiteralPath $settings) { (Get-Item -LiteralPath $settings).LastWriteTime = Get-Date }
    }
}

# VS Code: a theme's vscode.json names a marketplace theme to install and
# select. settings.json is JSONC, so it is edited in place rather than
# round-tripped through a strict parser, as omarchy-theme-set-vscode does.
function Update-VSCode {
    if (Test-Toggle 'skip-vscode-theme-changes') { return }
    $descriptor = Join-Path $CurrentTheme 'vscode.json'
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code -or -not (Test-Path -LiteralPath $descriptor) -or -not $env:APPDATA) { return }

    $spec = [IO.File]::ReadAllText($descriptor) | ConvertFrom-Json
    $name = ''; $extension = ''
    if ($spec.PSObject.Properties['name']) { $name = [string]$spec.name }
    if ($spec.PSObject.Properties['extension']) { $extension = [string]$spec.extension }
    if ($name -notmatch '^[^\x00-\x1f"\\]+$') { return }
    if ($extension -match '^[A-Za-z0-9._-]+$') {
        $installed = & $code.Source --list-extensions 2>$null
        if (-not ($installed -contains $extension)) { & $code.Source --install-extension $extension 2>&1 | Out-Null }
    }

    $settings = Join-Parts $env:APPDATA 'Code' 'User' 'settings.json'
    $text = if (Test-Path -LiteralPath $settings) { [IO.File]::ReadAllText($settings) } else { "{`n}`n" }
    $pattern = '("workbench\.colorTheme"\s*:\s*")[^"]*(")'
    if ($text -match $pattern) {
        $text = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + $name + $m.Groups[2].Value })
    }
    else {
        $text = ([regex]'\{').Replace($text, "{`n    `"workbench.colorTheme`": `"$name`",", 1)
    }
    Write-Utf8 $settings $text
}

function Wait-Mutex([Threading.Mutex]$Mutex) {
    # A background apply killed mid-run abandons its mutex; the next one may proceed.
    try { [void]$Mutex.WaitOne() } catch [Threading.AbandonedMutexException] { }
}

# Applies whatever theme is current when it runs, so of several quick switches
# the last one wins, and appliers take turns.
function Invoke-WindowsApply {
    $setMutex = New-Object System.Threading.Mutex($false, 'Local\omarchy-theme-set')
    $applyMutex = New-Object System.Threading.Mutex($false, 'Local\omarchy-theme-apply')
    Wait-Mutex $applyMutex
    try {
        Wait-Mutex $setMutex
        try {
            $colorsFile = Join-Path $CurrentTheme 'colors.toml'
            if (-not (Test-Path -LiteralPath $colorsFile)) { return }
            $colors = Resolve-ThemeColors (Read-ColorsToml $colorsFile) $CurrentTheme
            $background = Read-Text $CurrentBackground
        }
        finally {
            $setMutex.ReleaseMutex()
            $setMutex.Dispose()
        }

        $broadcast = $false
        if (-not (Test-Toggle 'skip-windows-mode')) { Set-WindowsMode $colors['mode']; $broadcast = $true }
        if (-not (Test-Toggle 'skip-windows-accent')) { Set-WindowsAccent $colors['accent']; $broadcast = $true }
        if ($broadcast) { Send-SettingChange 'ImmersiveColorSet' }
        if ($background -and -not (Test-Toggle 'skip-windows-wallpaper')) { Set-Wallpaper (ConvertTo-WallpaperFile $background) }
        Update-VSCode
    }
    finally {
        $applyMutex.ReleaseMutex()
        $applyMutex.Dispose()
    }
}

function Start-WindowsApply {
    $exe = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' })
    Start-Process -FilePath $exe -WindowStyle Hidden -ArgumentList "-NoProfile -NonInteractive -File `"$PSCommandPath`" apply-windows"
}

function Invoke-ThemeHooks([string]$Slug) {
    if (-not (Test-Path -LiteralPath $HookDir)) { return }
    foreach ($hook in Get-ChildItem -LiteralPath $HookDir -Filter '*.ps1' -File | Sort-Object Name) {
        try { & $hook.FullName $Slug } catch { Write-Warning "theme: hook $($hook.Name) failed: $_" }
    }
}

# --- commands -------------------------------------------------------------------------

function Get-ThemeList {
    $slugs = foreach ($dir in @($StockThemes, $UserThemes)) {
        if (Test-Path -LiteralPath $dir) { Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object { $_.Name } }
    }
    @($slugs | Sort-Object -Unique)
}

function Set-Theme([string]$Name, [bool]$Advance = $true) {
    $slug = ConvertTo-ThemeSlug $Name
    if (-not (Test-ThemeSlug $slug)) { throw "Invalid theme name: $Name" }
    if (@(Get-ThemeSources $slug).Count -eq 0) { throw "Theme '$slug' does not exist. See: theme list" }

    # One switch at a time: staging reuses a single next-theme directory.
    $mutex = New-Object System.Threading.Mutex($false, 'Local\omarchy-theme-set')
    [void]$mutex.WaitOne()
    try {
        $previous = Read-Text $CurrentName
        $previousBackground = Read-Text $CurrentBackground
        if ($previous -and $previousBackground) { Write-Utf8 (Join-Path $BackgroundMemory $previous) $previousBackground }

        [void](New-StagedTheme $slug)
        $background = Select-ThemeBackground $slug $previous $Advance
        if ($background) { Write-Utf8 $CurrentBackground $background }
        elseif (Test-Path -LiteralPath $CurrentBackground) { Remove-Item -LiteralPath $CurrentBackground -Force }
    }
    finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }

    if ($script:OnWindows) {
        Update-WindowsTerminal
        if ($Wait) { Invoke-WindowsApply } else { Start-WindowsApply }
    }
    Invoke-ThemeHooks $slug
    Write-Host "Theme set to $(ConvertTo-DisplayName $slug)"
}

function Set-NextBackground {
    $slug = Read-Text $CurrentName
    if (-not $slug) { throw 'No theme is set yet. Run: theme set <name>' }
    $background = Select-ThemeBackground $slug $slug $true
    if (-not $background) { Write-Host "No background was found for $(ConvertTo-DisplayName $slug)"; return }
    Write-Utf8 $CurrentBackground $background
    Write-Utf8 (Join-Path $BackgroundMemory $slug) $background
    if ($script:OnWindows) { Set-Wallpaper (ConvertTo-WallpaperFile $background) }
    Write-Host "Background: $(Split-Path -Leaf $background)"
}

function Install-Theme([string]$Url) {
    if (-not $Url) { throw 'Usage: theme install <git-repo-url>   (browse https://omarchy.org/themes/)' }
    if ($Url.StartsWith('-') -or $Url -match '^[A-Za-z][A-Za-z0-9+.-]*::') { throw "Refusing suspicious git URL: $Url" }
    $path = $Url
    if ($path -notmatch '://' -and $path -match '^[^/]*:') { $path = $path.Substring($path.IndexOf(':') + 1) }
    $leaf = ($path.TrimEnd('/') -split '/')[-1]
    $slug = ((($leaf -replace '\.git$', '') -replace '^omarchy-', '') -replace '-theme$', '').ToLowerInvariant()
    if (-not (Test-ThemeSlug $slug)) { throw "'$Url' does not give a usable theme name." }
    $target = Join-Path $UserThemes $slug
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Path $UserThemes -Force | Out-Null
    git clone -- $Url $target
    if ($LASTEXITCODE -ne 0) { throw 'Failed to clone theme repo.' }
    Set-Theme $slug
}

function Remove-Theme([string]$Name) {
    $slug = ConvertTo-ThemeSlug $Name
    if (-not (Test-ThemeSlug $slug)) { throw "Invalid theme name: $Name" }
    $target = Join-Path $UserThemes $slug
    if (-not (Test-Path -LiteralPath $target)) { throw "'$slug' is not one of your themes in $UserThemes" }
    if ((Read-Text $CurrentName) -eq $slug) { throw "'$slug' is the current theme; switch to another first." }
    Remove-Item -LiteralPath $target -Recurse -Force
    Write-Host "Removed $(ConvertTo-DisplayName $slug)"
}

switch ($Command.ToLowerInvariant()) {
    'list' { Get-ThemeList | ForEach-Object { ConvertTo-DisplayName $_ } }
    'current' {
        $slug = Read-Text $CurrentName
        if ($slug) { ConvertTo-DisplayName $slug } else { Write-Host 'No theme set. Run: theme set <name>' }
    }
    'set' {
        if ($Rest.Count -eq 0) { throw 'Usage: theme set <name>   (see: theme list)' }
        Set-Theme ($Rest -join ' ')
    }
    # Re-render the current theme after its sources or templates change,
    # keeping the wallpaper.
    'refresh' {
        $slug = Read-Text $CurrentName
        if ($slug -and @(Get-ThemeSources $slug).Count -gt 0) { Set-Theme $slug $false }
        elseif ($IfUnset -and -not $slug) { Set-Theme $IfUnset }
        elseif ($slug) { throw "The current theme '$slug' no longer exists." }
        else { throw 'No theme is set yet. Run: theme set <name>' }
    }
    'bg' {
        if ($Rest.Count -ge 1 -and $Rest[0] -eq 'next') { Set-NextBackground }
        else { throw 'Usage: theme bg next' }
    }
    'install' { Install-Theme ($Rest | Select-Object -First 1) }
    'remove' { Remove-Theme ($Rest -join ' ') }
    # Internal: the background half of set, started by Start-WindowsApply.
    'apply-windows' {
        $problems = try { Invoke-WindowsApply 3>&1 | Out-String } catch { "theme: $_" }
        if ($problems.Trim()) { [IO.File]::AppendAllText($ApplyLog, "$(Get-Date -Format s) $($problems.Trim())`r`n", $Utf8) }
    }
    default { throw 'Usage: theme list | current | set <name> [-Wait] | refresh [-IfUnset <name>] [-Wait] | bg next | install <git-url> | remove <name>' }
}
