$ErrorActionPreference='Stop'
# Never emit raw exceptions, return URLs, codes or states to the error stream.
try {
    # Positional $args avoids parameter-binding errors echoing an untrusted URL before this catch.
    if($args.Count -ne 2){throw 'Invalid invocation.'}
    $Root=[string]$args[0];$Link=[string]$args[1]
    . "$PSScriptRoot/Core.ps1"
    . "$PSScriptRoot/Windows.ps1"
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((Get-CallbackProtocolKey)+'\ProfileLauncherOwner')
    try {
        if(!$key -or $key.GetValue('LauncherRoot') -cne $Root -or $key.GetValue('LauncherScript') -cne $PSCommandPath -or !(Test-CallbackOwner $key)){throw 'Routing session ended.'}
    } finally {if($key){$key.Dispose()}}
    Invoke-LauncherCallback $Root $Link
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show('The authorization return could not be delivered. Keep the launcher open, then retry connecting from the intended profile. No authorization details were logged.','Plugin authorization')
    exit 1
}
