# Windows Terminal Dev Setup
# Windows Terminal + PowerShell 7 + Starship + Nerd Font
# + Yazi + zoxide + eza + bat
# + cmd AutoRun jump to Windows Terminal PowerShell 7

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    if ([string]::IsNullOrWhiteSpace($machinePath)) {
        $env:Path = $userPath
        return
    }

    if ([string]::IsNullOrWhiteSpace($userPath)) {
        $env:Path = $machinePath
        return
    }

    $env:Path = "$machinePath;$userPath"
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    Write-Step "Installing $Name"

    try {
        winget install `
            --id $Id `
            -e `
            --accept-source-agreements `
            --accept-package-agreements `
            --silent
    } catch {
        Write-Warn "Failed or already installed: $Name"
        Write-Warn $_.Exception.Message
    }
}

Write-Step 'Checking winget'

if (-not (Test-Command winget)) {
    Write-Host 'winget not found. Please install App Installer from Microsoft Store first.' -ForegroundColor Red
    exit 1
}

Write-Step 'Installing packages via winget'

$packages = @(
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' },
    @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7' },
    @{ Id = 'Git.Git'; Name = 'Git for Windows' },
    @{ Id = 'Starship.Starship'; Name = 'Starship' },
    @{ Id = 'DEVCOM.JetBrainsMonoNerdFont'; Name = 'JetBrainsMono Nerd Font' },
    @{ Id = 'sxyazi.yazi'; Name = 'Yazi' },
    @{ Id = 'ajeetdsouza.zoxide'; Name = 'zoxide' },
    @{ Id = 'eza-community.eza'; Name = 'eza' },
    @{ Id = 'sharkdp.bat'; Name = 'bat' }
)

foreach ($pkg in $packages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}

Write-Step 'Refreshing PATH'
Refresh-Path

Write-Step 'Creating Starship config'

$configDir = Join-Path $HOME '.config'
$starshipConfig = Join-Path $configDir 'starship.toml'

New-Item -ItemType Directory -Path $configDir -Force | Out-Null

if (Test-Path $starshipConfig) {
    $backup = "$starshipConfig.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $starshipConfig $backup -Force
    Write-Warn "Existing starship.toml backed up to: $backup"
}

$starshipUrl = 'https://raw.githubusercontent.com/justhalfbit/ghostty-terminal-config/main/starship/starship.toml'

try {
    Invoke-WebRequest -Uri $starshipUrl -OutFile $starshipConfig
    Write-Ok "Downloaded Starship config to: $starshipConfig"
} catch {
    Write-Warn 'Failed to download remote starship.toml. Trying built-in Starship preset.'

    Refresh-Path

    if (Test-Command starship) {
        starship preset catppuccin-powerline -o $starshipConfig
        Write-Ok 'Generated catppuccin-powerline preset.'
    } else {
        Write-Warn 'starship command not found in current session. Reopen terminal and run:'
        Write-Host "starship preset catppuccin-powerline -o `"$starshipConfig`""
    }
}

Write-Step 'Configuring Yazi file detection'

$gitFileExeCandidates = @(
    'C:\Program Files\Git\usr\bin\file.exe',
    'C:\Program Files (x86)\Git\usr\bin\file.exe',
    "$env:LOCALAPPDATA\Programs\Git\usr\bin\file.exe"
)

$gitFileExe = $gitFileExeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitFileExe) {
    [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $gitFileExe, 'User')
    $env:YAZI_FILE_ONE = $gitFileExe
    Write-Ok "Set YAZI_FILE_ONE=$gitFileExe"
} else {
    Write-Warn 'Git file.exe not found. Reopen terminal after Git installation, or set YAZI_FILE_ONE manually.'
}

Write-Step 'Configuring PowerShell 7 profile'

$pwshProfileDir = Join-Path $HOME 'Documents\PowerShell'
$pwshProfile = Join-Path $pwshProfileDir 'Microsoft.PowerShell_profile.ps1'

New-Item -ItemType Directory -Path $pwshProfileDir -Force | Out-Null

if (-not (Test-Path $pwshProfile)) {
    New-Item -ItemType File -Path $pwshProfile -Force | Out-Null
}

$profileContent = Get-Content $pwshProfile -Raw -ErrorAction SilentlyContinue
if ($null -eq $profileContent) {
    $profileContent = ''
}

$blockStart = '# >>> windows-terminal-starship-yazi >>>'
$blockEnd = '# <<< windows-terminal-starship-yazi <<<'

if ($profileContent -match [regex]::Escape($blockStart)) {
    $pattern = '(?s)' + [regex]::Escape($blockStart) + '.*?' + [regex]::Escape($blockEnd)
    $profileContent = [regex]::Replace($profileContent, $pattern, '')
}

$profileBlock = @'

# >>> windows-terminal-starship-yazi >>>

# Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# zoxide smart cd
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Remove built-in aliases so eza can take over.
Remove-Item Alias:ls -ErrorAction SilentlyContinue
Remove-Item Alias:dir -ErrorAction SilentlyContinue

function ls {
    eza --icons --group-directories-first @args
}

function ll {
    eza -l --icons --group-directories-first @args
}

function la {
    eza -la --icons --group-directories-first @args
}

function lt {
    eza --tree --icons --level=2 @args
}

function cat {
    bat --paging=never @args
}

# Open Yazi and cd to the last directory after exit.
function y {
    $tmp = New-TemporaryFile

    try {
        yazi @args --cwd-file="$tmp"
        $cwd = Get-Content -Path "$tmp" -Raw -ErrorAction SilentlyContinue

        if ($cwd) {
            $cwd = $cwd.Trim()
        }

        if ($cwd -and (Test-Path -LiteralPath $cwd) -and $cwd -ne $PWD.Path) {
            Set-Location -LiteralPath $cwd
        }
    } finally {
        Remove-Item -Path "$tmp" -Force -ErrorAction SilentlyContinue
    }
}

# <<< windows-terminal-starship-yazi <<<
'@

Set-Content -Path $pwshProfile -Value ($profileContent.TrimEnd() + "`r`n" + $profileBlock) -Encoding UTF8

Write-Ok "PowerShell 7 profile configured: $pwshProfile"

Write-Step 'Configuring Windows Terminal settings'

$wtSettingsCandidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
)

$wtSettings = $wtSettingsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($wtSettings) {
    try {
        $wtBackup = "$wtSettings.pre-wt-starship-yazi.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $wtSettings $wtBackup -Force

        $json = Get-Content $wtSettings -Raw | ConvertFrom-Json
        $profiles = @($json.profiles.list)

        $pwshWtProfile = $profiles | Where-Object {
            $_.name -eq 'PowerShell' -or
            $_.commandline -match 'pwsh(\.exe)?'
        } | Select-Object -First 1

        if ($pwshWtProfile) {
            $json.defaultProfile = $pwshWtProfile.guid
            Write-Ok 'Windows Terminal default profile set to PowerShell 7.'
        } else {
            Write-Warn 'PowerShell 7 profile not found in Windows Terminal settings.'
        }

        if (-not $json.profiles.defaults) {
            $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
        }

        if (-not $json.profiles.defaults.font) {
            $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) -Force
        }

        $json.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'JetBrainsMono Nerd Font' -Force

        $json | ConvertTo-Json -Depth 100 | Set-Content $wtSettings -Encoding UTF8

        Write-Ok 'Windows Terminal font set to JetBrainsMono Nerd Font.'
        Write-Warn "Windows Terminal settings backup: $wtBackup"
    } catch {
        Write-Warn 'Could not automatically edit Windows Terminal settings.'
        Write-Warn $_.Exception.Message
    }
} else {
    Write-Warn 'Windows Terminal settings.json not found. Open Windows Terminal once, then set default profile/font manually.'
}

Write-Step 'Setting Windows Terminal as default terminal application'

try {
    $startupKey = 'HKCU:\Console\%%Startup'

    if (-not (Test-Path $startupKey)) {
        New-Item -Path $startupKey -Force | Out-Null
    }

    New-ItemProperty `
        -Path $startupKey `
        -Name 'DelegationConsole' `
        -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}' `
        -PropertyType String `
        -Force | Out-Null

    New-ItemProperty `
        -Path $startupKey `
        -Name 'DelegationTerminal' `
        -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}' `
        -PropertyType String `
        -Force | Out-Null

    Write-Ok 'Default terminal application set to Windows Terminal.'
} catch {
    Write-Warn 'Failed to set Windows Terminal as default terminal application.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Configuring cmd AutoRun jump to Windows Terminal PowerShell 7'

try {
    $cmdKey = 'HKCU:\Software\Microsoft\Command Processor'

    if (-not (Test-Path $cmdKey)) {
        New-Item -Path $cmdKey -Force | Out-Null
    }

    $cmdAutoRun = 'if not defined WT_SESSION (start "" wt -p "PowerShell" -d "%CD%" & exit)'

    New-ItemProperty `
        -Path $cmdKey `
        -Name 'AutoRun' `
        -Value $cmdAutoRun `
        -PropertyType String `
        -Force | Out-Null

    Write-Ok 'cmd AutoRun configured.'
    Write-Warn "Tip: use 'cmd /d' if you need to bypass AutoRun temporarily."
} catch {
    Write-Warn 'Failed to configure cmd AutoRun.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Done'

Write-Host ''
Write-Host 'Please close all terminal windows, then open Windows Terminal.' -ForegroundColor Green
Write-Host ''
Write-Host 'Test commands:' -ForegroundColor Cyan
Write-Host '  $PSVersionTable.PSVersion'
Write-Host '  starship --version'
Write-Host '  yazi'
Write-Host '  y'
Write-Host '  z workf'
Write-Host '  ls'
Write-Host '  ll'
Write-Host '  eza --version'
Write-Host '  bat --version'
Write-Host ''
Write-Host 'If icons are garbled, set Windows Terminal font manually:' -ForegroundColor Yellow
Write-Host '  Windows Terminal -> Settings -> Defaults -> Appearance -> Font face -> JetBrainsMono Nerd Font'
Write-Host ''
Write-Host 'If cmd AutoRun causes trouble, run:' -ForegroundColor Yellow
Write-Host '  cmd /d'
Write-Host 'or use rollback.ps1.'
