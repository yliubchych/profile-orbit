. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
Test-Case 'Hotkey definitions bind the launcher and up to nine stable profile IDs' {
    $root=New-TestRoot;$a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $keys=@(Get-LauncherHotkeyDefinitions $root)
    Assert-Equal 3 $keys.Count
    Assert-Equal 'launcher' $keys[0].Target
    Assert-Equal $a.Id $keys[1].Target;Assert-Equal $b.Id $keys[2].Target
    Assert-Equal 49 $keys[1].Key
    $null=Update-LauncherProfile $root $a.Id 'Renamed' '#9BE4CC'
    Assert-Equal $a.Id @(Get-LauncherHotkeyDefinitions $root)[1].Target
}
Test-Case 'Two launcher processes share one instance and signal focus to the original' {
    $root=New-TestRoot;$worker=Join-Path $PSScriptRoot 'Instance.Worker.ps1'
    $a=Start-Process powershell.exe -ArgumentList ('-NoProfile -File "'+$worker+'" -Root "'+$root+'" -Hold') -PassThru -WindowStyle Hidden
    try {
        $ready=Join-Path $root 'ready'
        for($n=0;$n -lt 80 -and !(Test-Path $ready);$n++){Start-Sleep -Milliseconds 100}
        Assert-True (Test-Path $ready)
        $b=Start-Process powershell.exe -ArgumentList ('-NoProfile -File "'+$worker+'" -Root "'+$root+'"') -PassThru -WindowStyle Hidden
        try{Assert-True ($b.WaitForExit(10000));Assert-Equal 0 $b.ExitCode}finally{$b.Dispose()}
        Assert-True ($a.WaitForExit(10000));Assert-Equal 0 $a.ExitCode
        Assert-Equal 'focused' ([IO.File]::ReadAllText((Join-Path $root 'result')))
        $session=New-LauncherSession $root
        try{Assert-True $session.Owned}finally{Close-LauncherSession $session}
    } finally {$a.Dispose()}
}
Test-Case 'Hotkeys handle an empty store and cap profile bindings at nine without changing metadata' {
    $root=New-TestRoot
    $keys=@(Get-LauncherHotkeyDefinitions $root)
    Assert-Equal 1 $keys.Count
    Assert-Equal 'launcher' $keys[0].Target
    $profiles=@(1..11 | ForEach-Object {Add-LauncherProfile $root "Profile $_" '#9BE4CC'})
    $path=Join-Path $root 'launcher.json';$before=[IO.File]::ReadAllText($path)
    $keys=@(Get-LauncherHotkeyDefinitions $root)
    Assert-Equal 10 $keys.Count
    Assert-Equal @(10..18) @($keys | Select-Object -Skip 1 | ForEach-Object {$_.Id})
    Assert-Equal @(49..57) @($keys | Select-Object -Skip 1 | ForEach-Object {$_.Key})
    Assert-Equal @($profiles | Select-Object -First 9 | ForEach-Object {$_.Id}) @($keys | Select-Object -Skip 1 | ForEach-Object {$_.Target})
    Assert-Equal 'Ctrl+Alt+Shift+9' $keys[9].Label
    Assert-Equal $before ([IO.File]::ReadAllText($path))
}
Complete-Tests
