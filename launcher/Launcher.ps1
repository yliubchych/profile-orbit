param(
    [string]$Profile='UI',
    [string]$DataRoot=(Join-Path $PSScriptRoot 'profiles'),
    [switch]$Detached
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Windows.ps1"
if ($Profile -eq 'UI' -and !$Detached) {
    # Hidden windows can still keep a Windows Terminal tab alive.
    $child=[Diagnostics.Process]::Start((New-LauncherUIStartInfo $PSCommandPath $DataRoot))
    $child.Dispose()
    exit 0
}
$profileRoot=Get-CanonicalRoot $DataRoot
if ($Profile -eq 'Check') {
    $report=Get-LauncherDiagnostic $profileRoot
    Write-Output ($report|ConvertTo-Json -Depth 10)
    if($report.Checks -contains 'app-missing' -or $report.Checks -contains 'metadata-invalid'){exit 1}
    exit 0
}
if ($Profile -ne 'UI') {
    if ($Profile -eq 'Both') {
        $items=@(Get-LauncherProfiles $profileRoot)
        for($i=0;$i -lt $items.Count;$i++) {
            if ($i -gt 0) { Start-Sleep -Seconds 15 }
            $null=Start-CodexProfile $items[$i].Id
        }
    } else { $null=Start-CodexProfile $Profile }
    exit 0
}
. "$PSScriptRoot/UI.ps1"
$session=New-LauncherSession $profileRoot
if(!$session.Owned){Close-LauncherSession $session;exit 0}
try {
    $form=New-LauncherForm $profileRoot
    $form.Tag.Session=$session
    try { [void]$form.ShowDialog() } finally { $form.Dispose() }
} catch {
    [void][Windows.Forms.MessageBox]::Show((Get-LauncherUserMessage 'metadata-invalid'),'Could not open profile launcher')
    exit 1
} finally {Close-LauncherSession $session}
