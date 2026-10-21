$ErrorActionPreference='Stop'
try {
    if($args.Count -ne 2){exit 1}
    $handler=[string]$args[0];$token=[string]$args[1]
    . "$PSScriptRoot/Core.ps1"
    . "$PSScriptRoot/CallbackRouting.ps1"
    Watch-LauncherCallbackRouting $handler $token
} catch {exit 1}
