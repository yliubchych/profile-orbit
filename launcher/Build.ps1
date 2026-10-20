param([string]$Output=(Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Release.ps1"
New-LauncherPackage $PSScriptRoot $Output
