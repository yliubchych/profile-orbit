. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
$profileRoot=New-TestRoot;$p=Add-LauncherProfile $profileRoot 'Synthetic' '#9BE4CC'
$script:Targets=@();$script:Stopped=@();$script:Query=0;$script:ChangeIdentity=$false
function Get-ProfileProcess($Path){
    $script:Query++
    if($script:ChangeIdentity -and $script:Query -gt 1){[pscustomobject]@{ProcessId=999;CreationDate='replacement'};return}
    $script:Targets|ForEach-Object {$_}
}
function Invoke-ProfileStopProcess($ProcessId){$script:Stopped+=@($ProcessId);$script:Targets=@()}
Test-Case 'Full close terminates only the uniquely rechecked selected process' {
    $script:Targets=@([pscustomobject]@{ProcessId=123;CreationDate='same'});$script:Query=0;$script:Stopped=@()
    $null=Stop-CodexProfileCore $p.Id
    Assert-Equal @(123) $script:Stopped
}
Test-Case 'Changed or ambiguous process identity prevents termination' {
    $script:Stopped=@();$script:Query=0;$script:ChangeIdentity=$true;$script:Targets=@([pscustomobject]@{ProcessId=123;CreationDate='same'})
    Assert-Throws {Stop-CodexProfileCore $p.Id} '*changed*'
    Assert-Equal 0 $script:Stopped.Count
    $script:ChangeIdentity=$false;$script:Targets=@([pscustomobject]@{ProcessId=123},[pscustomobject]@{ProcessId=124})
    Assert-Throws {Stop-CodexProfileCore $p.Id} '*More than one*'
    Assert-Equal 0 $script:Stopped.Count
}
Complete-Tests
