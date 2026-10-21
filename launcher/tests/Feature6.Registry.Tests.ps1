. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../CallbackRouting.ps1"
# Exercise real registry semantics under a disposable non-protocol key, never Software\Classes\codex.
$script:TestKey='Software\ProfileLauncherTests\'+[guid]::NewGuid().ToString('N')
$script:LockName=Get-LauncherLockName $script:TestKey 'test-protocol'
function Get-CallbackProtocolKey {return $script:TestKey}
function Get-CallbackRoutingLockName {return $script:LockName}
function Notify-CallbackAssociation {}
function Start-CallbackGuard {}
function Get-EffectiveCallbackCommand {
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\shell\open\command')
    try {return $key.GetValue('')}finally{$key.Dispose()}
}
function Clear-TestRegistration {
    if($script:TestKey -notmatch '^Software\\ProfileLauncherTests\\[a-f0-9]{32}$'){throw 'Unsafe test key'}
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($script:TestKey,$false)
}
$root=New-TestRoot;$handler=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../Callback.ps1'))
try {
    Test-Case 'Automatic callback registration restores the previous absence and disable is idempotent' {
        $registration=Enable-LauncherCallbackRouting $root $handler
        try {
            Assert-Equal (Get-CallbackHandlerCommand $root $handler) (Get-EffectiveCallbackCommand)
            Assert-Throws {Enable-LauncherCallbackRouting $root $handler} '*Exit the launcher*'
        } finally {Disable-LauncherCallbackRouting $registration}
        Disable-LauncherCallbackRouting $registration
        Assert-Equal $null ([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey))
    }
    Test-Case 'An existing custom protocol handler is preserved' {
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($script:TestKey)
        try {$key.SetValue('','owner-handler')}finally{$key.Dispose()}
        try {
            Assert-Throws {Enable-LauncherCallbackRouting $root $handler} '*custom*'
            $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey)
            try {Assert-Equal 'owner-handler' $key.GetValue('')}finally{$key.Dispose()}
        } finally {Clear-TestRegistration}
    }
    Test-Case 'Edited nested registry content is retained on disable' {
        $registration=Enable-LauncherCallbackRouting $root $handler
        $key=New-VolatileCallbackKey ([Microsoft.Win32.Registry]::CurrentUser) ($script:TestKey+'\shell\owner-extra')
        $key.Dispose()
        try {
            Disable-LauncherCallbackRouting $registration
            $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\shell\owner-extra')
            try {Assert-True ($null -ne $key)}finally{if($key){$key.Dispose()}}
            Assert-Equal $null ([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\shell\open\command'))
        }
        finally {Clear-TestRegistration}
        Assert-True $registration.Closed
    }
    Test-Case 'An empty existing protocol stub is restored byte-for-byte in value names, types and contents' {
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($script:TestKey)
        try {$key.SetValue('','URL:codex');$key.SetValue('URL Protocol','')}finally{$key.Dispose()}
        try {
            $registration=Enable-LauncherCallbackRouting $root $handler
            Disable-LauncherCallbackRouting $registration
            $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey)
            try {
                Assert-Equal 0 $key.SubKeyCount
                Assert-Equal @('','URL Protocol') @($key.GetValueNames() | Sort-Object)
                Assert-Equal 'URL:codex' $key.GetValue('')
                Assert-Equal '' $key.GetValue('URL Protocol')
                Assert-Equal 'String' $key.GetValueKind('').ToString()
                Assert-Equal 'String' $key.GetValueKind('URL Protocol').ToString()
            } finally {$key.Dispose()}
        } finally {Clear-TestRegistration}
    }
    Test-Case 'A replacement command written by another app survives cleanup' {
        $registration=Enable-LauncherCallbackRouting $root $handler
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\shell\open\command',$true)
        try {$key.SetValue('','owner-replacement')}finally{$key.Dispose()}
        try {
            Disable-LauncherCallbackRouting $registration
            Assert-Equal 'owner-replacement' (Get-EffectiveCallbackCommand)
        } finally {Clear-TestRegistration}
    }
    Test-Case 'Windows association mismatch rolls back registration and releases its lock' {
        function Get-EffectiveCallbackCommand {return 'other-owner'}
        Assert-Throws {Enable-LauncherCallbackRouting $root $handler} '*different default*'
        Assert-Equal $null ([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey))
        function Get-EffectiveCallbackCommand {
            $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\shell\open\command')
            try {return $key.GetValue('')}finally{$key.Dispose()}
        }
        $registration=Enable-LauncherCallbackRouting $root $handler
        Disable-LauncherCallbackRouting $registration
    }
    Test-Case 'Stale owned registration is recovered but an active installation cannot be removed' {
        $registration=Enable-LauncherCallbackRouting $root $handler
        try {
            Assert-Throws {Remove-LauncherCallbackRegistration $handler -RequireInactive} '*Exit the launcher*'
            $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey+'\ProfileLauncherOwner',$true)
            try {$key.SetValue('LauncherOwnerStart','stale-start')}finally{$key.Dispose()}
            Remove-LauncherCallbackRegistration $handler -RequireInactive
            Assert-Equal $null ([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey))
        } finally {Disable-LauncherCallbackRouting $registration}
    }
    Test-Case 'Setup failure removes temporary registration before returning an error' {
        function Notify-CallbackAssociation {throw 'synthetic notification failure'}
        Assert-Throws {Enable-LauncherCallbackRouting $root $handler} '*synthetic*'
        Assert-Equal $null ([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey))
        function Notify-CallbackAssociation {}
        $registration=Enable-LauncherCallbackRouting $root $handler
        Disable-LauncherCallbackRouting $registration
    }
    Test-Case 'A separate watchdog restores routing after its synthetic launcher process is killed' {
        $marker=Join-Path (New-TestRoot) 'ready'
        $worker=Join-Path $PSScriptRoot 'Callback.Crash.Worker.ps1'
        $arguments='-NoProfile -File "'+$worker+'" -Key "'+$script:TestKey+'" -Marker "'+$marker+'"'
        $process=Start-Process powershell.exe -ArgumentList $arguments -PassThru -WindowStyle Hidden
        try {
            for($i=0;$i -lt 100 -and !(Test-Path $marker);$i++){Start-Sleep -Milliseconds 100}
            Assert-True (Test-Path $marker)
            $process.Kill();Assert-True ($process.WaitForExit(5000))
            $exists=$true
            for($i=0;$i -lt 100 -and $exists;$i++) {
                $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:TestKey)
                $exists=($null -ne $key);if($key){$key.Dispose()}
                if($exists){Start-Sleep -Milliseconds 100}
            }
            Assert-Equal $false $exists
        } finally {if(!$process.HasExited){$process.Kill()};$process.Dispose()}
    }
} finally {Clear-TestRegistration}
Complete-Tests
