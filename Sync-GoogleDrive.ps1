# =============================================================================
#  Sync-GoogleDrive.ps1
#  Syncs a local Documents folder with a Google Drive Documents folder.
#  Supports nested folders and all file types.
#  Requires: rclone  (https://rclone.org)
# =============================================================================

param (
    [string] $LocalPath   = "<path_to_local_documents_folder>",
    [string] $RemoteName  = "gdrive",
    [string] $RemotePath  = "<path_to_remote_folder_on_google_drive>",
    [string] $Mode        = "bisync",
    [switch] $DryRun,
    [switch] $Setup,
    [string] $LogDir      = "<path_to_log_directory>"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Validate Mode ------------------------------------------------------------
$validModes = @("push", "pull", "bisync")
if ($validModes -notcontains $Mode) {
    Write-Host "ERROR: -Mode must be one of: push, pull, bisync" -ForegroundColor Red
    exit 1
}

# -- Helper functions ---------------------------------------------------------
function Write-Header  { param($m) Write-Host "`n$m" -ForegroundColor Cyan }
function Write-Success { param($m) Write-Host "  OK   $m" -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "  WARN $m" -ForegroundColor Yellow }
function Write-Err     { param($m) Write-Host "  FAIL $m" -ForegroundColor Red }
function Write-Info    { param($m) Write-Host "  .... $m" -ForegroundColor Gray }

# -- Banner -------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host "     Google Drive <-> Local Documents Sync             " -ForegroundColor Cyan
Write-Host "               powered by rclone                       " -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
#  STEP 1 - Check rclone is installed
# =============================================================================
Write-Header "Checking prerequisites..."

$rcloneCmd = Get-Command rclone -ErrorAction SilentlyContinue
if ($null -eq $rcloneCmd) {
    Write-Err "rclone is not installed or not in PATH."
    Write-Host ""
    Write-Host "  Install options:" -ForegroundColor Yellow
    Write-Host "    Winget : winget install Rclone.Rclone" -ForegroundColor Yellow
    Write-Host "    Scoop  : scoop install rclone" -ForegroundColor Yellow
    Write-Host "    Manual : https://rclone.org/downloads/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  After installing, re-run with -Setup to configure Google Drive." -ForegroundColor Yellow
    exit 1
}
Write-Success "rclone found: $($rcloneCmd.Source)"

# =============================================================================
#  STEP 2 - First-time Google Drive setup
# =============================================================================
if ($Setup) {
    Write-Header "Running rclone config for Google Drive..."
    Write-Info "A browser window will open to authorise Google Drive access."
    Write-Info "When prompted for a remote name, enter: $RemoteName"
    Write-Info "Choose 'Google Drive' from the storage type list."
    Write-Host ""
    rclone config
    Write-Host ""
    Write-Success "Setup complete. Re-run without -Setup to start syncing."
    exit 0
}

# =============================================================================
#  STEP 3 - Verify the remote exists in rclone config
# =============================================================================
$remoteList  = rclone listremotes 2>&1
$remoteCheck = $remoteList | Where-Object { $_ -match "^${RemoteName}:" }
if ($null -eq $remoteCheck) {
    Write-Err "Remote '$RemoteName' is not configured in rclone."
    Write-Warn "Run:  .\Sync-GoogleDrive.ps1 -Setup"
    exit 1
}
Write-Success "Remote '$RemoteName' is configured."

# =============================================================================
#  STEP 4 - Validate local path
# =============================================================================
if (-not (Test-Path $LocalPath)) {
    Write-Err "Local path not found: $LocalPath"
    Write-Info "Pass a custom path:  -LocalPath 'D:\MyFolder'"
    exit 1
}

$remoteFull = "${RemoteName}:${RemotePath}"
$dryNote    = if ($DryRun) { "  [DRY RUN - no changes will be made]" } else { "" }

Write-Success "Local  : $LocalPath"
Write-Success "Remote : $remoteFull"
Write-Success "Mode   : $Mode$dryNote"

# =============================================================================
#  STEP 5 - Prepare log directory
# =============================================================================
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile   = Join-Path $LogDir "sync_$timestamp.log"

# =============================================================================
#  STEP 6 - Build shared rclone flags
# =============================================================================
$flags = @(
    "--log-level",        "INFO",
    "--log-file",         $logFile,
    "--transfers",        "8",
    "--checkers",         "16",
    "--drive-chunk-size", "128M",
    "--fast-list",
    "--progress"
)
if ($DryRun) {
    $flags += "--dry-run"
}

# =============================================================================
#  STEP 7 - Execute sync
# =============================================================================
Write-Header "Starting sync  [ $Mode ] ..."
$startTime = Get-Date

try {

    if ($Mode -eq "push") {
        Write-Info "Direction: Local --> Google Drive"
        Write-Info "Files deleted locally will also be removed from Drive."
        & rclone sync $LocalPath $remoteFull @flags

    } elseif ($Mode -eq "pull") {
        Write-Info "Direction: Google Drive --> Local"
        Write-Info "Files deleted on Drive will also be removed locally."
        & rclone sync $remoteFull $LocalPath @flags

    } elseif ($Mode -eq "bisync") {
        Write-Info "Direction: Both ways - newest file wins on conflict."

        $stateDir = "$env:APPDATA\rclone\bisync"
        $hasState = $false

        if (Test-Path $stateDir) {
            $stateFiles = Get-ChildItem $stateDir -Filter "*.path1" -ErrorAction SilentlyContinue
            if ($null -ne $stateFiles -and $stateFiles.Count -gt 0) {
                $hasState = $true
            }
        }

        if (-not $hasState) {
            Write-Warn "First bisync run - performing initial baseline (--resync)."
            Write-Warn "All files from both sides will be merged. No deletions on first run."
            & rclone bisync $LocalPath $remoteFull --resync @flags
        } else {
            & rclone bisync $LocalPath $remoteFull @flags
        }
    }

    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        $elapsed = (Get-Date) - $startTime
        $seconds = [math]::Round($elapsed.TotalSeconds, 1)
        Write-Host ""
        Write-Success "Sync completed successfully in $seconds seconds."
        Write-Success "Log saved to: $logFile"
    } else {
        Write-Err "rclone exited with code $exitCode. Check the log:"
        Write-Err $logFile
        exit $exitCode
    }

} catch {
    Write-Err "Unexpected error: $_"
    Write-Info "Log: $logFile"
    exit 1
}

# =============================================================================
#  STEP 8 - Auto-purge logs older than 30 days
# =============================================================================
Get-ChildItem $LogDir -Filter "sync_*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  Tip: Use -DryRun to preview changes before they happen." -ForegroundColor DarkGray
Write-Host ""
