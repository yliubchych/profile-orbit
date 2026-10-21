param([string]$Key,[string]$Marker,[switch]$Watch,[string]$Token)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../CallbackRouting.ps1"
$script:FixtureKey=$Key;$script:Worker=$PSCommandPath
$handler=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../Callback.ps1'))
function Get-CallbackProtocolKey {return $script:FixtureKey}
function Get-CallbackRoutingLockName {return (Get-LauncherLockName $script:FixtureKey 'crash-test')}
function Notify-CallbackAssociation {}
function Get-EffectiveCallbackCommand {
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:FixtureKey+'\shell\open\command')
    try{return $key.GetValue('')}finally{$key.Dispose()}
}
function Start-CallbackGuard($Script,$Token) {
    $arguments='-NoProfile -File "'+$script:Worker+'" -Key "'+$script:FixtureKey+'" -Watch -Token "'+$Token+'"'
    $guard=Start-Process powershell.exe -ArgumentList $arguments -PassThru -WindowStyle Hidden
    $guard.Dispose()
}
if($Watch){Watch-LauncherCallbackRouting $handler $Token;exit 0}
$registration=Enable-LauncherCallbackRouting $PSScriptRoot $handler
[IO.File]::WriteAllText($Marker,'ready')
# Parent test terminates this synthetic process without running finally.
Start-Sleep -Seconds 60
Disable-LauncherCallbackRouting $registration
