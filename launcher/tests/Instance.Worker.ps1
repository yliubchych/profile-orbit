param([string]$Root,[switch]$Hold)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Core.ps1"
$session=New-LauncherSession $Root
try {
    if($Hold) {
        if(!$session.Owned){throw 'First instance did not own its session'}
        [IO.File]::WriteAllText((Join-Path $Root 'ready'),'ready')
        if(!$session.FocusEvent.WaitOne(12000)){throw 'Focus request was not signaled'}
        [IO.File]::WriteAllText((Join-Path $Root 'result'),'focused')
    } elseif($session.Owned){throw 'Duplicate instance was accepted'}
} finally {Close-LauncherSession $session}
