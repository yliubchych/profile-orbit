. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../CallbackRouting.ps1"
Test-Case 'Authorization picker requires an explicit profile selection and supports cancellation' {
    $targets=@([pscustomobject]@{Id='default';Name='Default ChatGPT window'},[pscustomobject]@{Id='a'*32;Name='Personal'})
    $form=New-CallbackTargetDialog $targets
    try {
        Assert-Equal 2 $form.Tag.List.Items.Count
        Assert-Equal (-1) $form.Tag.List.SelectedIndex
        Assert-Equal $false $form.Tag.Continue.Enabled
        $form.Tag.List.SelectedIndex=1
        Assert-True $form.Tag.Continue.Enabled
        Assert-Equal ('a'*32) $form.Tag.List.SelectedItem.Id
        Assert-Equal 'Cancel' $form.CancelButton.DialogResult.ToString()
    } finally {$form.Dispose()}
}
Complete-Tests
