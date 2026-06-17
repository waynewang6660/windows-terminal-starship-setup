# Rollback script for Windows Terminal Dev Setup
# It removes:
# - cmd AutoRun jump
# - Windows Terminal default terminal delegation registry values
# - PowerShell profile block added by install.ps1
# - YAZI_FILE_ONE user environment variable
#
# It restores backed-up config files when available.

$ErrorActionPreference = 'Stop'

$script:StateDir = Join-Path $env:LOCALAPPDATA 'WindowsTerminalStarshipSetup'
$script:StatePath = Join-Path $script:StateDir 'state.json'

function Write-Step {
    param([string]$Message)
    Write-Host ''
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

function Load-State {
    if (-not (Test-Path $script:StatePath)) {
        return $null
    }

    try {
        return Get-Content $script:StatePath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
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

function Restore-FileFromBackup {
    param(
        [string]$TargetPath,
        [string]$BackupPath,
        [string]$BackupDirectory,
        [string]$BackupFilter,
        [string]$Label
    )

    $source = $null
    if ($BackupPath -and (Test-Path $BackupPath)) {
        $source = Get-Item $BackupPath
    } elseif ($BackupDirectory -and $BackupFilter) {
        $source = Get-ChildItem $BackupDirectory -Filter $BackupFilter -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    if ($null -eq $source) {
        Write-Warn "No backup found for $Label."
        return
    }

    $targetDirectory = Split-Path $TargetPath -Parent
    if ($targetDirectory -and -not (Test-Path $targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    Copy-Item $source.FullName $TargetPath -Force
    Write-Ok "Restored $Label from: $($source.FullName)"
}

function Restore-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [bool]$WasPresent,
        $OriginalValue,
        [string]$Label
    )

    if ($WasPresent) {
        New-ItemProperty `
            -Path $Path `
            -Name $Name `
            -Value $OriginalValue `
            -PropertyType String `
            -Force | Out-Null
        Write-Ok "Restored $Label."
    } else {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        Write-Ok "Removed $Label."
    }
}

Write-Step 'Restoring cmd AutoRun'

try {
    $cmdKey = 'HKCU:\Software\Microsoft\Command Processor'
    $state = Load-State

    if (Test-Path $cmdKey) {
        if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'CmdAutoRunWasPresent') {
            if ($state.CmdAutoRunWasPresent) {
                New-ItemProperty `
                    -Path $cmdKey `
                    -Name 'AutoRun' `
                    -Value $state.CmdAutoRunOriginalValue `
                    -PropertyType String `
                    -Force | Out-Null
                Write-Ok 'Restored previous cmd AutoRun value.'
            } else {
                Remove-ItemProperty -Path $cmdKey -Name 'AutoRun' -ErrorAction SilentlyContinue
                Write-Ok 'Removed cmd AutoRun.'
            }
        } else {
            Write-Warn 'No install state found. Leaving cmd AutoRun unchanged.'
        }
    } else {
        Write-Warn 'Command Processor registry key not found.'
    }
} catch {
    Write-Warn 'Failed to restore cmd AutoRun.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Restoring Windows Terminal default terminal delegation values'

try {
    $startupKey = 'HKCU:\Console\%%Startup'
    $state = Load-State

    if (Test-Path $startupKey) {
        if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'DelegationConsoleWasPresent') {
            Restore-RegistryValue -Path $startupKey -Name 'DelegationConsole' -WasPresent ([bool]$state.DelegationConsoleWasPresent) -OriginalValue $state.DelegationConsoleOriginalValue -Label 'DelegationConsole'
        } else {
            Write-Warn 'No recorded DelegationConsole state found. Leaving it unchanged.'
        }

        if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'DelegationTerminalWasPresent') {
            Restore-RegistryValue -Path $startupKey -Name 'DelegationTerminal' -WasPresent ([bool]$state.DelegationTerminalWasPresent) -OriginalValue $state.DelegationTerminalOriginalValue -Label 'DelegationTerminal'
        } else {
            Write-Warn 'No recorded DelegationTerminal state found. Leaving it unchanged.'
        }
    } else {
        Write-Warn 'Default terminal startup registry key not found.'
    }
} catch {
    Write-Warn 'Failed to restore default terminal delegation values.'
    Write-Warn $_.Exception.Message
}

Write-Step 'Removing PowerShell profile block'

$pwsh7Profile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
$winPsProfile = Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

Remove-ProfileBlock -ProfilePath $pwsh7Profile
Remove-ProfileBlock -ProfilePath $winPsProfile

Write-Step 'Restoring Starship config backup'

$starshipConfig = Join-Path (Join-Path $HOME '.config') 'starship.toml'
$state = Load-State

if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'StarshipConfigBackup' -and (Test-Path $state.StarshipConfigBackup)) {
    Restore-FileFromBackup -TargetPath $starshipConfig -BackupPath $state.StarshipConfigBackup -Label 'starship.toml'
} else {
    Write-Warn 'No recorded Starship backup found. Leaving starship.toml unchanged.'
}

Write-Step 'Restoring Windows Terminal settings backup'

$wtSettingsDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$wtSettingsPath = Join-Path $wtSettingsDir 'settings.json'

if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'WindowsTerminalSettingsBackup' -and (Test-Path $state.WindowsTerminalSettingsBackup)) {
    Restore-FileFromBackup -TargetPath $wtSettingsPath -BackupPath $state.WindowsTerminalSettingsBackup -Label 'Windows Terminal settings'
} else {
    Write-Warn 'No recorded Windows Terminal settings backup found. Leaving settings.json unchanged.'
}

Write-Step 'Restoring YAZI_FILE_ONE user environment variable'

try {
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains 'YaziFileOneWasPresent') {
        if ($state.YaziFileOneWasPresent) {
            [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $state.YaziFileOneOriginalValue, 'User')
            $env:YAZI_FILE_ONE = $state.YaziFileOneOriginalValue
            Write-Ok 'Restored YAZI_FILE_ONE.'
        } else {
            [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $null, 'User')
            Remove-Item Env:YAZI_FILE_ONE -ErrorAction SilentlyContinue
            Write-Ok 'Removed YAZI_FILE_ONE.'
        }
    } else {
        Write-Warn 'No install state found. Leaving YAZI_FILE_ONE unchanged.'
    }
} catch {
    Write-Warn 'Failed to restore YAZI_FILE_ONE.'
    Write-Warn $_.Exception.Message
}

if (Test-Path $script:StatePath) {
    Remove-Item $script:StatePath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Done'

Write-Host ''
Write-Host 'Rollback completed.' -ForegroundColor Green
Write-Host 'Please close all terminal windows and reopen them.'
Write-Host ''
Write-Host 'Notes:' -ForegroundColor Yellow
Write-Host '  - Installed packages were not uninstalled.'
Write-Host '  - If install state or a backup is missing, the script leaves unrelated user values unchanged.'
Write-Host '  - Use cmd /d to bypass AutoRun if needed before rollback takes effect.'
