# Rollback script for Windows Terminal Dev Setup
# It removes:
# - cmd AutoRun jump
# - Windows Terminal default terminal delegation registry values
# - PowerShell profile block added by install.ps1
# - YAZI_FILE_ONE user environment variable
#
# It does NOT uninstall packages by default.

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

function Remove-ProfileBlock {
    param([string]$ProfilePath)

    if (-not (Test-Path $ProfilePath)) {
        Write-Warn "Profile not found: $ProfilePath"
        return
    }

    $content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue

    if ($null -eq $content) {
        $content = ''
    }

    $blockStart = '# >>> windows-terminal-starship-yazi >>>'
    $blockEnd = '# <<< windows-terminal-starship-yazi <<<'

    if ($content -match [regex]::Escape($blockStart)) {
        $backup = "$ProfilePath.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $ProfilePath $backup -Force

        $pattern = '(?s)' + [regex]::Escape($blockStart) + '.*?' + [regex]::Escape($blockEnd)
        $newContent = [regex]::Replace($content, $pattern, '').Trim()

        Set-Content -Path $ProfilePath -Value $newContent -Encoding UTF8

        Write-Ok "Removed profile block from: $ProfilePath"
        Write-Warn "Backup: $backup"
    } else {
        Write-Warn "No managed profile block found in: $ProfilePath"
    }
}

Write-Step 'Removing cmd AutoRun'

try {
    $cmdKey = 'HKCU:\Software\Microsoft\Command Processor'

    if (Test-Path $cmdKey) {
        Remove-ItemProperty -Path $cmdKey -Name 'AutoRun' -ErrorAction SilentlyContinue
        Write-Ok 'Removed cmd AutoRun.'
    } else {
        Write-Warn 'Command Processor registry key not found.'
    }
} catch {
    Write-Warn 'Failed to remove cmd AutoRun.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Removing Windows Terminal default terminal delegation values'

try {
    $startupKey = 'HKCU:\Console\%%Startup'

    if (Test-Path $startupKey) {
        Remove-ItemProperty -Path $startupKey -Name 'DelegationConsole' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $startupKey -Name 'DelegationTerminal' -ErrorAction SilentlyContinue
        Write-Ok 'Removed default terminal delegation values.'
    } else {
        Write-Warn 'Default terminal startup registry key not found.'
    }
} catch {
    Write-Warn 'Failed to remove default terminal delegation values.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Removing PowerShell profile block'

$pwsh7Profile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
$winPsProfile = Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

Remove-ProfileBlock -ProfilePath $pwsh7Profile
Remove-ProfileBlock -ProfilePath $winPsProfile

Write-Step 'Removing YAZI_FILE_ONE user environment variable'

try {
    [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $null, 'User')
    Remove-Item Env:YAZI_FILE_ONE -ErrorAction SilentlyContinue
    Write-Ok 'Removed YAZI_FILE_ONE.'
} catch {
    Write-Warn 'Failed to remove YAZI_FILE_ONE.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Optional: restore Windows Terminal settings backup manually'

$wtSettingsDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'

if (Test-Path $wtSettingsDir) {
    $backups = Get-ChildItem $wtSettingsDir -Filter 'settings.json.pre-wt-starship-yazi.bak.*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($backups.Count -gt 0) {
        Write-Warn 'Found Windows Terminal settings backups:'
        $backups | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $($_.FullName)"
        }
        Write-Host ''
        Write-Host 'To restore the latest backup manually, run:' -ForegroundColor Yellow
        Write-Host "  Copy-Item `"$($backups[0].FullName)`" `"$wtSettingsDir\settings.json`" -Force"
    } else {
        Write-Warn 'No Windows Terminal settings backup found.'
    }
}

Write-Step 'Done'

Write-Host ''
Write-Host 'Rollback completed.' -ForegroundColor Green
Write-Host 'Please close all terminal windows and reopen them.'
Write-Host ''
Write-Host 'Notes:' -ForegroundColor Yellow
Write-Host '  - Installed packages were not uninstalled.'
Write-Host '  - Starship config at $HOME\.config\starship.toml was not deleted.'
Write-Host '  - Use cmd /d to bypass AutoRun if needed before rollback takes effect.'
