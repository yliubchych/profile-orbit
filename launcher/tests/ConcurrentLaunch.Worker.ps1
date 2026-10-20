param([string]$Root,[string]$Id)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
$profileRoot=$Root
function Get-ProfileProcess($Data) {
    if(Test-Path (Join-Path $profileRoot 'process-marker')) { [pscustomobject]@{ProcessId=123;CreationDate='synthetic'} }
}
function Open-ExistingProfile($Existing,$Name) { return 123 }
function Find-CodexApp { return 'mock.exe' }
function Get-FreeMemoryMB { return 4096 }
function Invoke-ProfileLaunch($App,$Data,$Codex) {
    Start-Sleep -Milliseconds 700
    [IO.File]::AppendAllText((Join-Path $profileRoot 'launch-count'),"launch`n")
    [IO.File]::WriteAllText((Join-Path $profileRoot 'process-marker'),'synthetic')
}
function Wait-ProfileWindow($Data,$Name) { return 123 }
$null=Start-CodexProfile $Id
