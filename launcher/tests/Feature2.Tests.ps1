. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
$root=New-TestRoot
$p=Add-LauncherProfile $root 'Test' '#AFCBFF'
$profileRoot=$root
$script:Processes=@(); $script:Windows=@(); $script:QueryError=$false
function Get-ProfileProcess($DataPath) { if($script:QueryError){throw 'Denied'}; $script:Processes | ForEach-Object {$_} }
function Get-ProfileWindows($ProcessId) { $script:Windows | ForEach-Object {$_} }
function Get-ProfileWindow($ProcessId) { if($script:Windows.Count){return [IntPtr]$script:Windows[0]}; return [IntPtr]::Zero }
function Find-CodexApp { return 'mock.exe' }
function Get-FreeMemoryMB { return 4096 }
function Invoke-ProfileLaunch { param($App,$Data,$Codex) $script:Launched++; $script:Processes=@([pscustomobject]@{ProcessId=123;CreationDate='same'});$script:Windows=@([IntPtr]1) }
function Open-ExistingProfile($Existing,$Name) { $script:Focused++; return $Existing.ProcessId }
function Wait-ProfileWindow($Data,$Name) { return 123 }
Test-Case 'Stopped profile offers Launch' {
    $s=Get-LauncherProfileState $root $p.Id
    Assert-Equal 'Stopped' $s.Status; Assert-Equal 'Launch' $s.Action
}
Test-Case 'Running profile with a visible/minimized window offers Focus' {
    $script:Processes=@([pscustomobject]@{ProcessId=123;CreationDate='same'});$script:Windows=@([IntPtr]1)
    $s=Get-LauncherProfileState $root $p.Id
    Assert-Equal 'Open' $s.Status;Assert-Equal 'Focus' $s.Action;Assert-Equal 1 $s.WindowCount
}
Test-Case 'Running without visible windows offers Reopen, not Stopped' {
    $script:Windows=@()
    $s=Get-LauncherProfileState $root $p.Id
    Assert-Equal 'Background' $s.Status;Assert-Equal 'Reopen' $s.Action
}
Test-Case 'Permission failure or ambiguous process identity is never reported as Stopped' {
    $script:QueryError=$true
    Assert-Equal 'Unknown' (Get-LauncherProfileState $root $p.Id).Status
    $script:QueryError=$false
    $script:Processes=@([pscustomobject]@{ProcessId=1},[pscustomobject]@{ProcessId=2})
    Assert-Equal 'Unavailable' (Get-LauncherProfileState $root $p.Id).Action
}
Test-Case 'Focus/reopen running profiles bypass cold-start RAM gate and never launch again' {
    $script:QueryError=$false
    function Get-FreeMemoryMB { throw 'RAM must not be queried for running profiles' }
    $script:Processes=@([pscustomobject]@{ProcessId=123;CreationDate='same'});$script:Windows=@([IntPtr]1)
    $script:Launched=0;$script:Focused=0
    $null=Start-CodexProfile $p.Id
    $null=Start-CodexProfile $p.Id
    Assert-Equal 0 $script:Launched;Assert-Equal 2 $script:Focused
}
Test-Case 'Cold launch then immediate repeat uses the same profile process' {
    $script:Processes=@();$script:Windows=@();$script:Launched=0;$script:Focused=0
    $null=Start-CodexProfile $p.Id
    $null=Start-CodexProfile $p.Id
    Assert-Equal 1 $script:Launched;Assert-Equal 1 $script:Focused
}
Test-Case 'Low RAM blocks a stopped profile without creating account directories' {
    function Get-FreeMemoryMB { return 100 }
    $r=New-TestRoot;$profileRoot=$r;$item=Add-LauncherProfile $r 'Low RAM' '#9BE4CC'
    $script:Processes=@();$script:Launched=0
    Assert-Throws { Start-CodexProfile $item.Id } '*RAM*'
    Assert-Equal 0 $script:Launched;Assert-True (!(Test-Path (Join-Path $r $item.Id)))
}
Test-Case 'Two launcher processes serialize a cold launch into exactly one app start' {
    $r=New-TestRoot; $item=Add-LauncherProfile $r 'Concurrent' '#9BE4CC'
    $worker=Join-Path $PSScriptRoot 'ConcurrentLaunch.Worker.ps1'
    $args='-NoProfile -File "'+$worker+'" -Root "'+$r+'" -Id '+$item.Id
    $a=Start-Process powershell.exe -ArgumentList $args -PassThru -WindowStyle Hidden
    $b=Start-Process powershell.exe -ArgumentList $args -PassThru -WindowStyle Hidden
    try {
        Assert-True ($a.WaitForExit(15000)); Assert-True ($b.WaitForExit(15000))
        Assert-Equal 0 $a.ExitCode;Assert-Equal 0 $b.ExitCode
        Assert-Equal 1 @([IO.File]::ReadAllLines((Join-Path $r 'launch-count'))).Count
    } finally { $a.Dispose();$b.Dispose() }
}
Complete-Tests
