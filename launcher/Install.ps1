param([string]$Destination=(Join-Path $env:LOCALAPPDATA 'ProfileLauncher'),[switch]$NoShortcut)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Release.ps1"
try {
    Install-Launcher $PSScriptRoot $Destination
    if(!$NoShortcut) {
        $path=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Profile Launcher.lnk'
        $result=New-LauncherShortcut $Destination $path
        if($result -eq 'PreservedOther'){Write-Output 'An unrelated desktop shortcut was preserved. Use Start.cmd in the installation folder.'}
    }
    Write-Output 'Installed. Open Profile Launcher on the desktop, or Start.cmd in the installation folder.'
} catch {Write-Error $_.Exception.Message;exit 1}
