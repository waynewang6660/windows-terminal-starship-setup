# Windows Terminal + Starship Setup for Windows

This repository packages the setup notes into two ready-to-run PowerShell scripts:

- `install.ps1` installs and configures Windows Terminal, PowerShell 7, Starship, Nerd Font, Yazi, zoxide, eza, and bat.
- `rollback.ps1` removes the registry and profile changes made by `install.ps1` without uninstalling apps.

## Requirements

- Windows 10 / Windows 11
- `winget` available
- Internet access for package installation

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
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/waynewang6660/windows-terminal-starship-setup/main/install.ps1 | iex"
```

Rollback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/waynewang6660/windows-terminal-starship-setup/main/rollback.ps1 | iex"
```

Safer install:

```powershell
irm https://raw.githubusercontent.com/waynewang6660/windows-terminal-starship-setup/main/install.ps1 -OutFile install.ps1
notepad .\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Optional flags:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -EnableCmdAutoRun -OverrideBuiltinAliases
```

## What the install script changes

- Installs the required tools with `winget`
- Uses the vendored `starship.toml` in this repository
- Configures PowerShell 7 profile helpers (`ll`, `la`, `lt`, `y` always; `ls`/`dir`/`cat` only with the optional flag)
- Sets `YAZI_FILE_ONE` for better file type detection
- Updates Windows Terminal defaults where possible
- Can optionally set `cmd.exe` to jump into Windows Terminal PowerShell 7
- Can optionally override the built-in `ls`, `dir`, and `cat` aliases for `eza` and `bat`

If you need the original `cmd.exe` behavior temporarily, run:

```powershell
cmd /d
```

## Security notes

- This script does not read browser passwords, SSH keys, tokens, or upload files.
- It may install packages through `winget`, modify the current user's PowerShell profile, update Windows Terminal settings, and optionally configure `cmd.exe` AutoRun.
- For safer installation, download and inspect the script before running it.

## Notes

- The scripts create backups when editing existing config files.
- Rollback restores the exact saved `AutoRun`, `YAZI_FILE_ONE`, and Windows Terminal delegation values when state is available.
- Rollback does not uninstall packages by default.
- If Windows Terminal icon fonts look broken, set the font manually to `JetBrainsMono Nerd Font` in Terminal settings.
