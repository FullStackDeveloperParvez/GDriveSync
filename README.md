# Google Drive Documents Sync

A PowerShell-based solution for syncing a local `Documents` folder with Google Drive on Windows. Supports nested folders, all file types, and three sync directions — powered by [rclone](https://rclone.org).

---

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
  - [Step 1 — Install rclone](#step-1--install-rclone)
  - [Step 2 — Verify rclone is in PATH](#step-2--verify-rclone-is-in-path)
  - [Step 3 — Fix PATH if rclone is not found](#step-3--fix-path-if-rclone-is-not-found)
  - [Step 4 — Allow PowerShell to run local scripts](#step-4--allow-powershell-to-run-local-scripts)
  - [Step 5 — Authorise Google Drive](#step-5--authorise-google-drive)
  - [Step 6 — Dry run before first sync](#step-6--dry-run-before-first-sync)
- [Usage](#usage)
  - [Option A — Double-click launcher](#option-a--double-click-launcher)
  - [Option B — PowerShell directly](#option-b--powershell-directly)
  - [Sync modes explained](#sync-modes-explained)
  - [All parameters reference](#all-parameters-reference)
- [Configuration Guide](#configuration-guide)
  - [Changing the local folder path](#changing-the-local-folder-path)
  - [Changing the Google Drive folder path](#changing-the-google-drive-folder-path)
  - [Changing the rclone remote name](#changing-the-rclone-remote-name)
  - [Changing the sync mode](#changing-the-sync-mode)
  - [Changing the log folder](#changing-the-log-folder)
- [Automating with Task Scheduler](#automating-with-task-scheduler)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)
- [How It Works](#how-it-works)

---

## Features

- **Two-way sync** — keeps both local and Google Drive in sync; newest file always wins on conflict
- **One-way push** — mirror local to Google Drive (Drive follows local exactly)
- **One-way pull** — mirror Google Drive to local (local follows Drive exactly)
- **Nested folder support** — recursively syncs all subfolders and files
- **All file types** — works with documents, images, videos, zip files, etc.
- **Dry run mode** — preview exactly what will change before committing
- **Automatic logging** — every run produces a timestamped log; logs older than 30 days are purged automatically
- **Task Scheduler integration** — optional XML to automate syncs on a schedule
- **Parallel transfers** — 8 concurrent transfers and 16 metadata checkers for fast syncs

---

## Project Structure

```
GoogleDriveSync/
|-- Sync-GoogleDrive.ps1   # Main sync script (all logic lives here)
|-- RunSync.bat            # Double-click launcher (no terminal needed)
|-- SyncTask.xml           # Windows Task Scheduler definition for automatic sync
|-- README.md              # This file
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Windows 10 / 11** | PowerShell 5.1 or later (included in Windows by default) |
| **rclone** | Free, open-source cloud sync tool — [rclone.org](https://rclone.org) |
| **Google Account** | The Google Drive account you want to sync with |
| **Internet connection** | Required during setup and during each sync run |

---

## Installation & Setup

Follow every step in order. Skipping steps is the most common cause of errors.

### Step 1 — Install rclone

Open **PowerShell** or **Command Prompt** and run one of the following:

**Option A — Winget (recommended, built into Windows 10/11):**
```powershell
winget install Rclone.Rclone
```

**Option B — Scoop:**
```powershell
scoop install rclone
```

**Option C — Manual install:**
1. Go to [https://rclone.org/downloads/](https://rclone.org/downloads/)
2. Download the **Windows 64-bit** zip file
3. Extract it to a permanent folder, e.g. `C:\Tools\rclone\`
4. Add that folder to your system PATH (see Step 3 below)

---

### Step 2 — Verify rclone is in PATH

Close and reopen PowerShell, then run:
```powershell
rclone version
```

Expected output (version numbers will vary):
```
rclone v1.68.0
- os/version: windows 10.0.22631 (64 bit)
- os/kernel: ...
```

If you see `rclone version` output, skip to **Step 4**.
If you see `The term 'rclone' is not recognized`, continue to **Step 3**.

---

### Step 3 — Fix PATH if rclone is not found

This happens when rclone is installed but Windows does not know where to find it.

**3a — Locate the rclone.exe file:**
```powershell
Get-ChildItem "$env:USERPROFILE\AppData\Local\Microsoft\WinGet\Packages" -Recurse -Filter "rclone.exe" -ErrorAction SilentlyContinue | Select-Object FullName
```

This will output a path like:
```
C:\Users\YourName\AppData\Local\Microsoft\WinGet\Packages\Rclone.Rclone_Microsoft.Winget.Source_8wekyb3d8bbwe\rclone.exe
```

**3b — Copy just the folder path (everything except `\rclone.exe`) and run:**
```powershell
$rcloneDir = "C:\Users\YourName\AppData\Local\Microsoft\WinGet\Packages\Rclone.Rclone_Microsoft.Winget.Source_8wekyb3d8bbwe"

[System.Environment]::SetEnvironmentVariable(
    "PATH",
    $env:PATH + ";" + $rcloneDir,
    [System.EnvironmentVariableTarget]::User
)
```

**3c — Reload the PATH in your current session:**
```powershell
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","User") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","Machine")
```

**3d — Confirm it works:**
```powershell
rclone version
```

---

### Step 4 — Allow PowerShell to run local scripts

By default, Windows blocks unsigned PowerShell scripts. Run this **once** in an elevated PowerShell (right-click → Run as Administrator):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

When prompted, press `Y` and Enter.

> **What this does:** `RemoteSigned` allows locally created scripts to run freely. Scripts downloaded from the internet must be signed. This is the standard developer setting and does not weaken security significantly.

**Alternative — unblock just this script (no admin required):**
```powershell
Unblock-File -Path "D:\Projects\GoogleDriveSync\Sync-GoogleDrive.ps1"
```

> Note: `RunSync.bat` uses `-ExecutionPolicy Bypass` internally, so double-clicking it always works regardless of this setting.

---

### Step 5 — Authorise Google Drive

Run the setup flag to link your Google Drive account:

```powershell
.\Sync-GoogleDrive.ps1 -Setup
```

The interactive rclone config wizard will start. Follow these steps exactly:

1. Type `n` and press Enter to create a **new remote**
2. When asked for a name, type `gdrive` and press Enter
3. When shown the storage type list, find and enter the number for **Google Drive**
4. Press Enter to leave `client_id` blank (use default)
5. Press Enter to leave `client_secret` blank (use default)
6. For scope, enter `1` (full access to all files)
7. Press Enter to leave `root_folder_id` blank
8. Press Enter to leave `service_account_file` blank
9. Type `n` for advanced config
10. Type `y` to use auto config — a browser window will open
11. Log in with your Google account and click **Allow**
12. Back in the terminal, type `n` (not a shared drive)
13. Type `y` to confirm the remote, then `q` to quit

Verify the remote was created:
```powershell
rclone listremotes
```
Expected output: `gdrive:`

---

### Step 6 — Dry run before first sync

Always preview before running a real sync, especially the first time:

```powershell
.\Sync-GoogleDrive.ps1 -DryRun
```

This shows every file that would be transferred or deleted **without actually doing anything**. Review the output carefully, then run without `-DryRun` when satisfied.

---

## Usage

### Option A — Double-click launcher

The easiest way. Just double-click `RunSync.bat`. No terminal needed.

To customise paths or mode, open `RunSync.bat` in Notepad and edit the variables at the top:

```bat
set LOCAL_PATH=%USERPROFILE%\Documents
set REMOTE_NAME=gdrive
set REMOTE_PATH=Documents
set MODE=bisync
set DRY_RUN=
```

To enable dry run, change the last line to:
```bat
set DRY_RUN=--DryRun
```

---

### Option B — PowerShell directly

Open PowerShell, navigate to the project folder, and run:

```powershell
# Default two-way sync (bisync)
.\Sync-GoogleDrive.ps1

# One-way push (local to Google Drive)
.\Sync-GoogleDrive.ps1 -Mode push

# One-way pull (Google Drive to local)
.\Sync-GoogleDrive.ps1 -Mode pull

# Dry run (preview changes only, nothing is modified)
.\Sync-GoogleDrive.ps1 -DryRun

# Custom local folder
.\Sync-GoogleDrive.ps1 -LocalPath "D:\Work\Projects"

# Custom Google Drive subfolder
.\Sync-GoogleDrive.ps1 -RemotePath "Backups\Work"

# All options combined
.\Sync-GoogleDrive.ps1 -LocalPath "D:\Work" -RemotePath "Work" -Mode push -DryRun
```

---

### Sync modes explained

| Mode | Direction | Deletions | Best for |
|---|---|---|---|
| `bisync` *(default)* | Both ways | Propagated both ways; newest file wins on conflict | Keeping two machines in sync |
| `push` | Local → Drive only | Files deleted locally are also deleted from Drive | Using local as the single source of truth |
| `pull` | Drive → Local only | Files deleted from Drive are also deleted locally | Downloading from Drive to a local machine |

> **Warning:** `push` and `pull` use `rclone sync`, which will **delete** files on the destination that don't exist on the source. Always use `-DryRun` first.

---

### All parameters reference

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-LocalPath` | String | `%USERPROFILE%\Documents` | Full path to the local folder to sync |
| `-RemoteName` | String | `gdrive` | Name of the rclone remote (set during setup) |
| `-RemotePath` | String | `Documents` | Folder path inside Google Drive |
| `-Mode` | String | `bisync` | Sync direction: `push`, `pull`, or `bisync` |
| `-DryRun` | Switch | Off | Preview changes without applying them |
| `-Setup` | Switch | Off | Launch the rclone Google Drive authorisation wizard |
| `-LogDir` | String | `%USERPROFILE%\Documents\SyncLogs` | Folder where log files are saved |

---

## Configuration Guide

### Changing the local folder path

**In `RunSync.bat`:**
```bat
set LOCAL_PATH=D:\Work\MyFolder
```

**In PowerShell:**
```powershell
.\Sync-GoogleDrive.ps1 -LocalPath "D:\Work\MyFolder"
```

**To change the default permanently in `Sync-GoogleDrive.ps1`**, edit line 7:
```powershell
# Before
[string] $LocalPath   = "$env:USERPROFILE\Documents",

# After (example)
[string] $LocalPath   = "D:\Work\MyFolder",
```

---

### Changing the Google Drive folder path

This controls which folder inside your Google Drive is used as the sync target.

**In `RunSync.bat`:**
```bat
set REMOTE_PATH=Backups\Work
```

**In PowerShell:**
```powershell
.\Sync-GoogleDrive.ps1 -RemotePath "Backups\Work"
```

**To change the default in `Sync-GoogleDrive.ps1`**, edit line 9:
```powershell
# Before
[string] $RemotePath  = "Documents",

# After (example — syncs to "My Drive > Backups > Work")
[string] $RemotePath  = "Backups\Work",
```

> Use forward slashes or backslashes for nested paths. To sync with the root of your Drive, set `RemotePath` to an empty string `""`.

---

### Changing the rclone remote name

The remote name must match exactly what you entered during `-Setup` (default: `gdrive`).

To check your configured remotes:
```powershell
rclone listremotes
```

**In `RunSync.bat`:**
```bat
set REMOTE_NAME=my_drive
```

**In `Sync-GoogleDrive.ps1`**, edit line 8:
```powershell
[string] $RemoteName  = "my_drive",
```

> If you want to use a different Google account, run `.\Sync-GoogleDrive.ps1 -Setup` again and give the new remote a different name (e.g. `gdrive_work`), then point `-RemoteName` to it.

---

### Changing the sync mode

**In `RunSync.bat`:**
```bat
set MODE=push
```

Valid values: `push`, `pull`, `bisync`

**In `Sync-GoogleDrive.ps1`**, edit line 10:
```powershell
[string] $Mode        = "push",
```

---

### Changing the log folder

Logs are saved to `%USERPROFILE%\Documents\SyncLogs` by default.

**In PowerShell:**
```powershell
.\Sync-GoogleDrive.ps1 -LogDir "D:\Logs\DriveSync"
```

**In `Sync-GoogleDrive.ps1`**, edit line 13:
```powershell
[string] $LogDir      = "D:\Logs\DriveSync"
```

Logs older than 30 days are automatically deleted. To change the retention period, find this line near the bottom of `Sync-GoogleDrive.ps1` and adjust the number:
```powershell
Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
#                                                         ^^^
#                                                  change this number
```

---

## Automating with Task Scheduler

`SyncTask.xml` runs the sync automatically every hour after you log in.

**Step 1 — Edit `SyncTask.xml`**

Open it in Notepad and replace both instances of the placeholder path:
```xml
<!-- Before -->
<Arguments>-NoProfile -ExecutionPolicy Bypass -File "C:\Users\YourName\Scripts\Sync-GoogleDrive.ps1" -Mode bisync</Arguments>
<WorkingDirectory>C:\Users\YourName\Scripts</WorkingDirectory>

<!-- After (use your actual folder path) -->
<Arguments>-NoProfile -ExecutionPolicy Bypass -File "D:\Projects\GoogleDriveSync\Sync-GoogleDrive.ps1" -Mode bisync</Arguments>
<WorkingDirectory>D:\Projects\GoogleDriveSync</WorkingDirectory>
```

**Step 2 — Import the task**

Run in an elevated Command Prompt (Run as Administrator):
```bat
schtasks /Create /XML "SyncTask.xml" /TN "GoogleDriveDocSync"
```

Or import manually:
1. Open **Task Scheduler** (search in Start Menu)
2. Click **Action → Import Task...**
3. Browse to `SyncTask.xml` and click Open
4. Review settings and click OK (Windows will ask for your password)

**Step 3 — Verify the task is registered:**
```bat
schtasks /Query /TN "GoogleDriveDocSync"
```

**To run the task immediately:**
```bat
schtasks /Run /TN "GoogleDriveDocSync"
```

**To remove the task:**
```bat
schtasks /Delete /TN "GoogleDriveDocSync" /F
```

---

## Logs

Every sync run creates a log file at:
```
%USERPROFILE%\Documents\SyncLogs\sync_YYYY-MM-DD_HH-mm-ss.log
```

Log files contain:
- Timestamp of every file transferred or deleted
- Errors and warnings
- Transfer speeds and file sizes
- Exit code

To view the latest log in PowerShell:
```powershell
Get-ChildItem "$env:USERPROFILE\Documents\SyncLogs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

Logs older than 30 days are automatically purged after each sync run.

---

## Troubleshooting

### `rclone is not installed or not in PATH`
rclone is installed but Windows cannot find it. Follow [Step 3](#step-3--fix-path-if-rclone-is-not-found) to add it to your PATH.

### `File cannot be loaded. The file is not digitally signed.`
PowerShell is blocking unsigned scripts. Run this once in an elevated PowerShell:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Or use `RunSync.bat` which bypasses this restriction automatically.

### `Remote 'gdrive' is not configured`
The Google Drive authorisation step was not completed. Run:
```powershell
.\Sync-GoogleDrive.ps1 -Setup
```

### `Unexpected token '{' in expression or statement`
The script file was saved with Unicode curly braces instead of ASCII ones (a copy-paste encoding issue). Re-download the original `Sync-GoogleDrive.ps1` file from this repository.

### `bisync: --resync required`
rclone bisync lost its state file (e.g. after a Windows profile change or manual cleanup). Delete the state folder and re-run:
```powershell
Remove-Item "$env:APPDATA\rclone\bisync" -Recurse -Force
.\Sync-GoogleDrive.ps1
```
The script will automatically detect the missing state and run with `--resync`.

### `Access denied` or `403 Forbidden` from Google Drive
The OAuth token may have expired or been revoked. Re-run setup to refresh it:
```powershell
.\Sync-GoogleDrive.ps1 -Setup
```

### Files are being deleted unexpectedly
You are likely in `push` or `pull` mode, which mirrors one side exactly including deletions. Switch to `bisync` mode, or use `-DryRun` first to confirm what will happen before running a real sync.

---

## How It Works

```
Local Documents Folder
        |
        |  rclone bisync / sync
        |
Google Drive Folder  (gdrive:Documents)
```

The script wraps [rclone](https://rclone.org), a battle-tested open-source tool that handles the Google Drive API communication, conflict detection, and transfer optimisation.

| rclone command | Used for |
|---|---|
| `rclone bisync` | Two-way sync (`bisync` mode) |
| `rclone sync A B` | One-way mirror from A to B (`push` / `pull` modes) |
| `rclone config` | Interactive remote setup (`-Setup` flag) |
| `rclone listremotes` | Verify configured remotes |

On the very first `bisync` run, rclone needs to establish a baseline of both sides (`--resync`). The script detects this automatically by checking for state files in `%APPDATA%\rclone\bisync\` and adds `--resync` only when needed.

---

## License

MIT — free to use, modify, and distribute.
