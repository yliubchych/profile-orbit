. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
$script:TestState='Stopped'
function Get-LauncherProfileState($Root,$Id) {
    $action=@{Stopped='Launch';Background='Reopen';Open='Focus';Unknown='Unavailable'}[$script:TestState]
    [pscustomobject]@{Status=$script:TestState;Action=$action;WindowCount=0}
}
Test-Case 'Live refresh updates state, action and unavailable button safely' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'Test' '#9BE4CC';$f=New-LauncherForm $root
    try {
        foreach($state in @('Stopped','Background','Open','Unknown')) {
            $script:TestState=$state
            Update-LauncherStatus $f
            Assert-Equal $state $f.Tag.Cards[$p.Id].StateLabel.Text
            Assert-Equal ($state -ne 'Unknown') $f.Tag.Cards[$p.Id].OpenButton.Enabled
            Assert-True ($f.Tag.Cards[$p.Id].OpenButton.Text -like ((Get-LauncherProfileState $root $p.Id).Action+'*'))
        }
        Assert-True ($f.Tag.StatusTimer.Interval -ge 1000)
    } finally { $f.Dispose() }
}
Complete-Tests
