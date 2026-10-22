. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
function Get-LauncherProfileState {param($Root,$Id) [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
Test-Case 'Updates are accessible from the launcher and tray; dialog distinguishes available and current' {
    $form=New-LauncherForm (New-TestRoot)
    try{
        Assert-True $form.Tag.UpdatesButton.Enabled
        Assert-True (@($form.Tag.TrayMenu.Items|Where-Object {$_.Text -eq 'Check for updates...'}).Count -eq 1)
        $dialog=New-LauncherUpdateDialog $form
        try{
            Set-LauncherUpdateResult $dialog $null
            Assert-Equal 'Check' $dialog.Tag.Mode
            Assert-True ($dialog.Tag.Message.Text -like '*up to date*')
            Set-LauncherUpdateResult $dialog ([pscustomobject]@{Version='0.2.0'})
            Assert-Equal 'Install' $dialog.Tag.Mode
            Assert-Equal 'Install and restart' $dialog.Tag.Action.Text
        }finally{$dialog.Dispose()}
    }finally{$form.Dispose()}
}
Test-Case 'Background check errors remain visible and retryable without exiting the launcher' {
    $form=New-LauncherForm (New-TestRoot);$dialog=New-LauncherUpdateDialog $form
    try{
        $ps=[PowerShell]::Create();$null=$ps.AddScript("throw 'Synthetic offline failure'")
        $handle=$ps.BeginInvoke()
        Assert-True $handle.AsyncWaitHandle.WaitOne(5000)
        $dialog.Tag.Job=@{PowerShell=$ps;Handle=$handle}
        Receive-LauncherUpdateTask $dialog
        Assert-True ($dialog.Tag.Message.Text -like '*Synthetic offline failure*')
        Assert-True $dialog.Tag.Action.Enabled
        Assert-Equal $null $dialog.Tag.Job
        Assert-Equal $false $form.Tag.AllowExit
    }finally{$dialog.Dispose();$form.Dispose()}
}
Test-Case 'Cancelling a completed download prevents installer launch' {
    $form=New-LauncherForm (New-TestRoot);$dialog=New-LauncherUpdateDialog $form
    try{
        $ps=[PowerShell]::Create();$null=$ps.AddScript("[pscustomobject]@{Version='0.2.0'}")
        $handle=$ps.BeginInvoke();Assert-True $handle.AsyncWaitHandle.WaitOne(5000)
        $dialog.Tag.Job=@{PowerShell=$ps;Handle=$handle};$dialog.Tag.Mode='Install';$dialog.Tag.CancelRequested=$true
        Receive-LauncherUpdateTask $dialog
        Assert-Equal $false $form.Tag.AllowExit
        Assert-Equal $null $dialog.Tag.Job
    }finally{$dialog.Dispose();$form.Dispose()}
}
Complete-Tests
