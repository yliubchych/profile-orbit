param([Parameter(Mandatory=$true)][string]$Request)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
. "$PSScriptRoot/Release.ps1"
. "$PSScriptRoot/Updates.ps1"
$destination=$null;$dataRoot=$null
try{
    $job=[IO.File]::ReadAllText($Request)|ConvertFrom-Json
    $destination=Assert-InstallDirectory $job.Destination
    $dataRoot=Get-CanonicalRoot $job.DataRoot
    $parent=Get-Process -Id $job.ParentId -ErrorAction SilentlyContinue
    if($parent -and $parent.StartTime.ToUniversalTime().Ticks -eq $job.ParentTicks){
        if(!$parent.WaitForExit(30000)){throw 'The launcher did not exit. Close it and retry the update.'}
    }
    Invoke-LauncherLock (Get-LauncherLockName $destination 'update') {
        Assert-LauncherUpdateTarget $destination
        $current=([IO.File]::ReadAllText((Join-Path $destination 'VERSION'))).Trim()
        if((Compare-LauncherVersion $job.Version $current) -le 0){throw 'The update is no longer newer than the installed version.'}
        # Recheck downloaded bytes after the original launcher exits.
        $source=Expand-LauncherUpdate $job.Archive (Join-Path (Split-Path $Request -Parent) 'verified') $job.Sha256 $job.Version
        Install-Launcher $source $destination
    }
}catch{
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show(('Update could not be completed. '+$_.Exception.Message),'Profile Launcher update')
}finally{
    if($destination -and $dataRoot -and (Test-Path -LiteralPath (Join-Path $destination 'Launcher.ps1'))){
        $info=New-LauncherUpdateStartInfo (Join-Path $destination 'Launcher.ps1') ('-DataRoot '+(ConvertTo-LauncherProcessArgument $dataRoot))
        $child=[Diagnostics.Process]::Start($info);if($child){$child.Dispose()}
    }
}
