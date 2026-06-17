# Windows Terminal + Starship Setup for Windows

This repository packages the setup notes into two ready-to-run PowerShell scripts:

- `install.ps1` installs and configures Windows Terminal, PowerShell 7, Starship, Nerd Font, Yazi, zoxide, eza, and bat.
- `rollback.ps1` removes the registry and profile changes made by `install.ps1` without uninstalling apps.

## Requirements

- Windows 10 / Windows 11
- `winget` available
- Internet access for package installation and Starship config download

## Run locally

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Rollback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rollback.ps1
```

## Run from GitHub

After you publish the repo, users can run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/<your-user>/<your-repo>/main/install.ps1 | iex"
```

Rollback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/<your-user>/<your-repo>/main/rollback.ps1 | iex"
```

## What the install script changes

- Installs the required tools with `winget`
- Downloads or generates `starship.toml`
- Configures PowerShell 7 profile helpers
- Sets `YAZI_FILE_ONE` for better file type detection
- Updates Windows Terminal defaults where possible
- Sets `cmd.exe` to jump into Windows Terminal PowerShell 7 by default

If you need the original `cmd.exe` behavior temporarily, run:

```powershell
cmd /d
```

## Notes

- The scripts create backups when editing existing config files.
- Rollback does not uninstall packages by default.
- If Windows Terminal icon fonts look broken, set the font manually to `JetBrainsMono Nerd Font` in Terminal settings.
