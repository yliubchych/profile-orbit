. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"

Test-Case 'Absent and corrupt event logs return no events without modifying the log' {
    $root=New-TestRoot;$path=Join-Path $root 'events.json'
    Assert-Equal 0 @(Read-LauncherEvents $root).Count
    Assert-True (!(Test-Path -LiteralPath $path))
    [IO.File]::WriteAllText($path,'broken-json')
    Assert-Equal 0 @(Read-LauncherEvents $root).Count
    Assert-Equal 'broken-json' ([IO.File]::ReadAllText($path))
}
Test-Case 'Event writes retain only the latest fifty events in order' {
    $root=New-TestRoot
    1..50 | ForEach-Object {Write-LauncherEvent $root 'launch' 'ok'}
    $before=@(Read-LauncherEvents $root)
    Write-LauncherEvent $root 'close' 'timeout'
    $events=@(Read-LauncherEvents $root)
    Assert-Equal 50 $events.Count
    Assert-Equal @($before | Select-Object -Skip 1) @($events | Select-Object -First 49)
    Assert-Equal 'close' $events[49].Action
    Assert-Equal 'timeout' $events[49].Code
    $stored=[IO.File]::ReadAllText((Join-Path $root 'events.json'))|ConvertFrom-Json
    Assert-Equal 50 @($stored).Count
}
Test-Case 'Event readers filter invalid fields and strip extra private properties' {
    $root=New-TestRoot;$path=Join-Path $root 'events.json'
    $json='[{"Time":"2026-10-20T00:00:00.000Z","Action":"setup","Code":"failed","Private":"synthetic-private"},{"Time":"invalid","Action":"launch","Code":"ok"},{"Time":"2026-10-20T00:00:00Z","Action":"private-action","Code":"ok"},{"Time":"2026-10-20T00:00:00Z","Action":"launch","Code":"private-code"}]'
    [IO.File]::WriteAllText($path,$json)
    $events=@(Read-LauncherEvents $root)
    Assert-Equal 1 $events.Count
    Assert-Equal @('Action','Code','Time') @($events[0].PSObject.Properties.Name | Sort-Object)
    Assert-Equal 'setup' $events[0].Action
    Assert-True (($events|ConvertTo-Json) -notmatch 'private')
    Assert-Equal $json ([IO.File]::ReadAllText($path))
}
Test-Case 'Invalid event writes preserve the existing log' {
    $root=New-TestRoot;Write-LauncherEvent $root 'project' 'ok'
    $path=Join-Path $root 'events.json';$before=[IO.File]::ReadAllText($path)
    Assert-Throws {Write-LauncherEvent $root 'invalid' 'ok'}
    Assert-Throws {Write-LauncherEvent $root 'launch' 'invalid'}
    Assert-Equal $before ([IO.File]::ReadAllText($path))
}
Test-Case 'Diagnostics report invalid app versions and unavailable memory without leaking exceptions' {
    $root=New-TestRoot
    $null=Add-LauncherProfile $root 'synthetic-private-name' '#9BE4CC'
    function Get-InstalledCodexInfo { [pscustomobject]@{Version='synthetic-private-version'} }
    function Get-FreeMemoryMB {throw 'synthetic-private-error'}
    function Get-LauncherProfileState { [pscustomobject]@{Status='synthetic-private-state'} }
    $report=Get-LauncherDiagnostic $root
    Assert-Equal @('app-missing','memory-unavailable') $report.Checks
    Assert-Equal 'Unavailable' $report.AppVersion
    Assert-Equal $null $report.FreeMemoryMB
    Assert-Equal @('Unknown') $report.ProfileStates
    Assert-True (($report|ConvertTo-Json -Depth 10) -notmatch 'synthetic-private')
}
Test-Case 'Low-memory diagnostics use the same 2560 MB boundary as launch guidance' {
    $root=New-TestRoot
    function Get-InstalledCodexInfo { [pscustomobject]@{Version='99.1.0.0'} }
    function Get-FreeMemoryMB {return 2559}
    $report=Get-LauncherDiagnostic $root
    Assert-Equal @('app-unverified','low-memory') $report.Checks
    function Get-FreeMemoryMB {return 2560}
    Assert-Equal @('app-unverified') (Get-LauncherDiagnostic $root).Checks
}
Complete-Tests
