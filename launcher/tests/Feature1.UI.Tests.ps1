. "$PSScriptRoot/TestHarness.ps1"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot/../Core.ps1"
$ui = Join-Path $PSScriptRoot '../UI.ps1'
if (Test-Path $ui) { . $ui }
function Find-CodexApp { throw 'No installed app needed for UI tests' }
function Start-CodexProfile { param($Name) $script:Opened=$Name }
function Stop-CodexProfile { param($Name) return 'Closed' }
function Get-LauncherProfileState { param($Root,$Id) return [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0} }
Test-Case 'Empty onboarding displays add-profile action' {
    $root=New-TestRoot
    $f=New-LauncherForm $root
    try { Assert-True $f.Tag.AddButton.Enabled; Assert-Equal 0 $f.Tag.Cards.Count; Assert-True ($f.Tag.EmptyLabel.Text -like '*first profile*') }
    finally { $f.Dispose() }
}
Test-Case 'Editor saves name/color through the same form used by onboarding' {
    $root=New-TestRoot
    $editor=New-ProfileEditor $root
    try {
        $editor.Tag.NameBox.Text='Client A'
        $editor.Tag.ColorBox.SelectedIndex=1
        Save-ProfileEditor $editor
        Assert-Equal 1 @(Get-LauncherProfiles $root).Count
        Assert-Equal 'Client A' @(Get-LauncherProfiles $root)[0].Name
    } finally { $editor.Dispose() }
}
Test-Case 'Edit form loads existing metadata; save retains its identity' {
    $root=New-TestRoot
    $p=Add-LauncherProfile $root 'Original' '#9BE4CC'
    $editor=New-ProfileEditor $root $p.Id
    try {
        Assert-Equal 'Original' $editor.Tag.NameBox.Text
        $editor.Tag.NameBox.Text='Renamed'
        Save-ProfileEditor $editor
        Assert-Equal $p.Id @(Get-LauncherProfiles $root)[0].Id
        Assert-Equal 'Renamed' @(Get-LauncherProfiles $root)[0].Name
    } finally { $editor.Dispose() }
}
Test-Case 'Profile cards display persisted name/color and stable identity' {
    $root=New-TestRoot
    $p=Add-LauncherProfile $root 'Client A' '#AFCBFF'
    $f=New-LauncherForm $root
    try {
        Assert-Equal 1 $f.Tag.Cards.Count
        Assert-Equal 'Client A' $f.Tag.Cards[$p.Id].NameLabel.Text
        Assert-Equal $p.Id $f.Tag.Cards[$p.Id].OpenButton.Tag
        Assert-Equal '#AFCBFF' ([Drawing.ColorTranslator]::ToHtml($f.Tag.Cards[$p.Id].OpenButton.BackColor))
    } finally { $f.Dispose() }
}
Complete-Tests
