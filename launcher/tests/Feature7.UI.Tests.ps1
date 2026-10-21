. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
function Get-LauncherProfileState {param($Root,$Id) [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
Test-Case 'Each card exposes Plugins and routes its own stable profile ID' {
    $root=New-TestRoot;$a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $form=New-LauncherForm $root
    try {
        $form.Tag.EnableHotkeys=$false
        $form.Show();[Windows.Forms.Application]::DoEvents()
        $script:Selected=$null
        function Invoke-LauncherPlugins($Root,$Id){$script:Selected=@($Root,$Id)}
        Assert-Equal $a.Id $form.Tag.Cards[$a.Id].PluginsButton.Tag
        $form.Tag.Cards[$b.Id].PluginsButton.PerformClick()
        Assert-Equal @($root,$b.Id) $script:Selected
        foreach($card in $form.Tag.Cards.Values) {
            Assert-True ($card.ProjectsButton.Right -lt $card.PluginsButton.Left)
            Assert-True ($card.PluginsButton.Right -le $card.Panel.Width)
        }
    } finally {$form.Dispose()}
}
Complete-Tests
