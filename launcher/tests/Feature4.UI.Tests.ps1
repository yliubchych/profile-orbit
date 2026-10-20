. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
Test-Case 'Diagnostics UI previews and exports the same redacted report' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'private-name' '#9BE4CC'
    function Get-InstalledCodexInfo {[pscustomobject]@{Version='26.1013.4894.0';Path='C:\private\ChatGPT.exe'}}
    function Get-FreeMemoryMB {return 4096}
    function Get-LauncherProfileState($Root,$Id){[pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
    $dialog=New-DiagnosticsWindow $root
    try {
        Assert-True (!$dialog.Tag.Preview.Text.Contains('private-name'))
        $path=Join-Path (New-TestRoot) 'report.json'
        Export-LauncherDiagnostic $dialog.Tag.Report $path
        Assert-Equal ($dialog.Tag.Report|ConvertTo-Json -Depth 10) ([IO.File]::ReadAllText($path))
    } finally {$dialog.Dispose()}
}
Complete-Tests
