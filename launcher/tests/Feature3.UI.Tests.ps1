. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../UI.ps1"
function Get-LauncherProfileState {param($Root,$Id) [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
Test-Case 'Each card exposes profile-bound projects and project manager displays saved shortcuts' {
    $root=New-TestRoot;$folder=New-TestRoot;$p=Add-LauncherProfile $root 'Client A' '#9BE4CC'
    $item=Add-LauncherProject $root $p.Id 'Site' $folder
    $f=New-LauncherForm $root
    $manager=New-ProjectManager $root $p.Id
    try {
        Assert-Equal $p.Id $f.Tag.Cards[$p.Id].ProjectsButton.Tag
        Assert-Equal 1 $manager.Tag.List.Items.Count
        Assert-Equal 'Site' $manager.Tag.List.Items[0].Name
        $manager.Tag.List.SelectedIndex=0
        $script:Opened=$null
        function Invoke-LauncherProject($Root,$Id,$ProjectId){$script:Opened=@($Root,$Id,$ProjectId)}
        Open-SelectedProject $manager
        Assert-Equal @($root,$p.Id,$item.Id) $script:Opened
    } finally { $manager.Dispose();$f.Dispose() }
}
Complete-Tests
