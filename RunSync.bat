@echo off
:: ============================================================
::  RunSync.bat  –  Launcher for Sync-GoogleDrive.ps1
::  Double-click this file to run the sync.
::  Edit the variables below to match your setup.
:: ============================================================

:: ── User-configurable settings ──────────────────────────────
set LOCAL_PATH=<path_to_local_documents_folder>
set REMOTE_NAME=gdrive
set REMOTE_PATH=<path_to_remote_folder_on_google_drive>
set MODE=bisync

:: Set DRY_RUN=--DryRun to preview without changing anything
set DRY_RUN=

:: ─────────────────────────────────────────────────────────────
:: Resolve the script's own directory so it works from anywhere
set SCRIPT_DIR=%~dp0

echo.
echo  ================================================
echo   Google Drive ^<-^> Local Documents Sync
echo  ================================================
echo   Local  : %LOCAL_PATH%
echo   Remote : %REMOTE_NAME%:%REMOTE_PATH%
echo   Mode   : %MODE%
echo  ================================================
echo.

:: Run PowerShell with execution-policy bypass (no admin needed)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Sync-GoogleDrive.ps1" ^
    -LocalPath  "%LOCAL_PATH%"  ^
    -RemoteName "%REMOTE_NAME%" ^
    -RemotePath "%REMOTE_PATH%" ^
    -Mode       "%MODE%"        ^
    %DRY_RUN%

echo.
pause
