. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
$profileRoot=New-TestRoot;$p=Add-LauncherProfile $profileRoot 'Test' '#9BE4CC'
$original=[pscustomobject]@{ProcessId=123;CreationDate='original'}
$script:Current=$original;$script:Visible=$true;$script:Launched=0;$script:Activated=0
function Get-ProfileWindow($ProcessId){if($script:Visible){return [IntPtr]1};return [IntPtr]::Zero}
function Get-ProfileProcess($Data){return $script:Current}
function Find-CodexApp {return 'mock.exe'}
function Invoke-ProfileLaunch($App,$Data,$Codex){$script:Launched++;$script:Visible=$true}
function Wait-ProfileWindow($Data,$Name){return 123}
function Set-ProfileWindowForeground($Window,$ProcessId){$script:Activated++;return $true}
Test-Case 'Visible profile activates its exact window without app relaunch' {
    $script:Visible=$true;$script:Launched=0;$script:Activated=0
    $null=Open-ExistingProfile $original $p.Id
    Assert-Equal 0 $script:Launched;Assert-Equal 1 $script:Activated
}
Test-Case 'Background profile requests one reopen, then repeated opens only focus' {
    $script:Visible=$false;$script:Launched=0;$script:Activated=0
    $null=Open-ExistingProfile $original $p.Id
    $null=Open-ExistingProfile $original $p.Id
    Assert-Equal 1 $script:Launched;Assert-Equal 2 $script:Activated
}
Test-Case 'Replaced process identity prevents focusing a different process' {
    $script:Visible=$true;$script:Activated=0;$script:Current=[pscustomobject]@{ProcessId=999;CreationDate='replacement'}
    Assert-Throws {Open-ExistingProfile $original $p.Id} '*changed*'
    Assert-Equal 0 $script:Activated
}
Complete-Tests
