param([string]$Destination=$PSScriptRoot)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Release.ps1"
try {
    $shortcut=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Profile Launcher.lnk'
    Uninstall-Launcher $Destination
    Remove-LauncherShortcut $Destination $shortcut
    Write-Output 'Launcher files removed where unchanged. Profile data, edited files and unknown files were preserved.'
} catch {Write-Error $_.Exception.Message;exit 1}
