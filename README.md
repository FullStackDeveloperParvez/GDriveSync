One-time setup (do this first)
1 — Install rclone
batwinget install Rclone.Rclone
2 — Authorise Google Drive (opens a browser tab)
powershell.\Sync-GoogleDrive.ps1 -Setup
When rclone asks for a name, type gdrive. Choose Google Drive, then follow the OAuth flow.
3 — Preview before the first real sync
powershell.\Sync-GoogleDrive.ps1 -DryRun
4 — Run the sync
batRunSync.bat          # double-click, or run from cmd

Sync modes
Pass -Mode to the .ps1 (or edit MODE= in RunSync.bat):
ModeBehaviourbisync (default)Two-way — newest file wins on conflictpushLocal → Drive only (Drive mirrors local, deletions included)pullDrive → Local only (local mirrors Drive, deletions included)

Automate it

Edit SyncTask.xml — replace C:\Users\YourName\Scripts\ with the actual folder where you saved the .ps1.
Import into Task Scheduler:

batschtasks /Create /XML "SyncTask.xml" /TN "GoogleDriveDocSync"
It will then sync every hour after you log in, silently in the background.

Logs are saved automatically to Documents\SyncLogs\ and purged after 30 days.
