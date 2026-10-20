. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
$release=Join-Path $PSScriptRoot '../Release.ps1';if(Test-Path $release){. $release}
Test-Case 'Release archive uses an allowlist and excludes all runtime/test/private files' {
    $out=New-TestRoot
    $package=New-LauncherPackage (Join-Path $PSScriptRoot '..') $out
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($package)
    try {
        $entries=@($zip.Entries | ForEach-Object {$_.FullName})
        Assert-Equal @(Get-LauncherReleaseFiles | Sort-Object) @($entries | Where-Object {$_ -ne 'package-manifest.json'} | Sort-Object)
        Assert-True (@($entries | Where-Object {$_ -match 'profiles/|auth|Cookies|tests/|backup|\.tmp'}).Count -eq 0)
    } finally {$zip.Dispose()}
}
Test-Case 'Fresh install, update and uninstall retain profile metadata and unknown files' {
    $dest=Join-Path (New-TestRoot) 'Installed'
    Install-Launcher (Join-Path $PSScriptRoot '..') $dest
    $data=Join-Path $dest 'profiles';$p=Add-LauncherProfile $data 'Synthetic' '#9BE4CC'
    $account=Join-Path $data ($p.Id+'/codex');$null=New-Item -ItemType Directory $account -Force
    [IO.File]::WriteAllText((Join-Path $account 'sentinel'),'test-only')
    [IO.File]::WriteAllText((Join-Path $dest 'keep.txt'),'owner-file')
    Install-Launcher (Join-Path $PSScriptRoot '..') $dest
    Assert-Equal 1 @(Get-LauncherProfiles $data).Count
    Uninstall-Launcher $dest
    Assert-True (!(Test-Path (Join-Path $dest 'Launcher.ps1')))
    Assert-Equal 'test-only' ([IO.File]::ReadAllText((Join-Path $account 'sentinel')))
    Assert-Equal 'owner-file' ([IO.File]::ReadAllText((Join-Path $dest 'keep.txt')))
}
Test-Case 'Installer rejects missing source files before altering a target' {
    $source=New-TestRoot;$dest=Join-Path (New-TestRoot) 'Installed'
    Assert-Throws {Install-Launcher $source $dest} '*release source*'
    Assert-True (!(Test-Path $dest))
}
Test-Case 'Install refuses unrelated target collisions and drive-root targets' {
    $dest=New-TestRoot;[IO.File]::WriteAllText((Join-Path $dest 'Launcher.ps1'),'owner-script')
    Assert-Throws {Install-Launcher (Join-Path $PSScriptRoot '..') $dest} '*unmanaged*'
    Assert-Equal 'owner-script' ([IO.File]::ReadAllText((Join-Path $dest 'Launcher.ps1')))
    Assert-Throws {Uninstall-Launcher ([IO.Path]::GetPathRoot($dest))}
}
Test-Case 'Tampered uninstall manifest cannot remove a file outside the installation' {
    $dest=Join-Path (New-TestRoot) 'Installed';Install-Launcher (Join-Path $PSScriptRoot '..') $dest
    $manifest=Join-Path $dest 'installation.json'
    $value=[IO.File]::ReadAllText($manifest)|ConvertFrom-Json
    $value.Files+=@('../outside.txt');[IO.File]::WriteAllText($manifest,($value|ConvertTo-Json -Depth 10))
    Assert-Throws {Uninstall-Launcher $dest} '*manifest*'
    Assert-True (Test-Path (Join-Path $dest 'Launcher.ps1'))
}
Test-Case 'Launch environment removes inherited agent context and API secrets' {
    $env:OPENAI_API_KEY='synthetic-secret';$env:CODEX_THREAD_ID='synthetic-thread';$env:CODEX_PROFILE='wrong-account';$env:CODEX_API_KEY='synthetic-other-secret'
    try {
        $start=New-ProfileStartInfo 'C:\App\ChatGPT.exe' 'C:\data\desktop' 'C:\data\codex' 'codex://threads/new?path=D%3A%5Cproject'
        Assert-Equal $null $start.EnvironmentVariables['OPENAI_API_KEY']
        Assert-Equal $null $start.EnvironmentVariables['CODEX_THREAD_ID']
        Assert-Equal $null $start.EnvironmentVariables['CODEX_PROFILE']
        Assert-Equal $null $start.EnvironmentVariables['CODEX_API_KEY']
        Assert-Equal 'C:\data\codex' $start.EnvironmentVariables['CODEX_HOME']
        Assert-Equal $false $start.UseShellExecute
        Assert-True ($start.Arguments.Contains('--user-data-dir="C:\data\desktop"'))
        Assert-Throws {New-ProfileStartInfo 'C:\App\ChatGPT.exe' 'C:\data' 'C:\codex' 'bad" & command'}
    } finally {Remove-Item Env:OPENAI_API_KEY,Env:CODEX_THREAD_ID,Env:CODEX_PROFILE,Env:CODEX_API_KEY -ErrorAction SilentlyContinue}
}
Test-Case 'Diagnostic export contains health facts but no names, paths, secrets or raw errors' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'private-client-name' '#9BE4CC'
    function Get-InstalledCodexInfo { [pscustomobject]@{Version='26.1013.4894.0';Path='C:\Users\private-user\App\ChatGPT.exe'} }
    function Get-FreeMemoryMB {return 4096}
    function Get-LauncherProfileState($Root,$Id){[pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
    Write-LauncherEvent $root 'launch' 'unavailable'
    $report=Get-LauncherDiagnostic $root
    $json=$report|ConvertTo-Json -Depth 10
    Assert-True ($json -notmatch 'private-client-name|private-user|auth\.json|OPENAI_API_KEY')
    Assert-True (!$json.Contains($root))
    Assert-Equal 1 $report.ProfileCount
    Assert-Equal '26.1013.4894.0' $report.AppVersion
    Assert-True ($report.Events.Count -gt 0)
    Assert-Throws {Write-LauncherEvent $root 'private prompt' 'secret error details'}
}
Test-Case 'Missing app and malformed metadata produce actionable health results' {
    $root=New-TestRoot
    function Get-InstalledCodexInfo {throw 'missing'}
    function Get-FreeMemoryMB {return 4096}
    $health=Get-LauncherDiagnostic $root
    Assert-True ($health.Checks -contains 'app-missing')
    [IO.File]::WriteAllText((Join-Path $root 'launcher.json'),'broken')
    $health=Get-LauncherDiagnostic $root
    Assert-True ($health.Checks -contains 'metadata-invalid')
    Assert-Equal 'broken' ([IO.File]::ReadAllText((Join-Path $root 'launcher.json')))
}
Test-Case 'Known builds and unverified future builds are distinguished honestly' {
    Assert-Equal 'LocallyChecked' (Get-LauncherCompatibility '26.1013.4894.0')
    Assert-Equal 'Unverified' (Get-LauncherCompatibility '99.1.0.0')
    Assert-True ((Get-LauncherUserMessage 'app-missing') -like '*Install*')
}
Test-Case 'A mid-update source read failure rolls back earlier managed file writes' {
    $source=New-TestRoot;$dest=Join-Path (New-TestRoot) 'Installed'
    foreach($file in Get-LauncherReleaseFiles){Copy-Item -LiteralPath (Join-Path (Join-Path $PSScriptRoot '..') $file) -Destination (Join-Path $source $file)}
    Install-Launcher $source $dest
    $before=(Get-FileHash (Join-Path $dest 'Core.ps1')).Hash
    [IO.File]::AppendAllText((Join-Path $source 'Core.ps1'),"`r`n# synthetic update`r`n")
    $locked=[IO.File]::Open((Join-Path $source 'VERSION'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try{Assert-Throws {Install-Launcher $source $dest} '*rolled back*'}finally{$locked.Dispose()}
    Assert-Equal $before (Get-FileHash (Join-Path $dest 'Core.ps1')).Hash
    $null=Read-InstallManifest $dest
}
Test-Case 'Uninstall preserves user-edited managed files' {
    $dest=Join-Path (New-TestRoot) 'Installed';Install-Launcher (Join-Path $PSScriptRoot '..') $dest
    [IO.File]::AppendAllText((Join-Path $dest 'Core.ps1'),"`r`n# owner edit")
    Uninstall-Launcher $dest
    Assert-True (Test-Path (Join-Path $dest 'Core.ps1'))
}
Test-Case 'Tampered log entries cannot inject names or extra diagnostic fields' {
    $root=New-TestRoot
    [IO.File]::WriteAllText((Join-Path $root 'events.json'),'[{"Time":"2026-10-20T00:00:00.000Z","Action":"launch","Code":"ok","Secret":"private-data"},{"Time":"bad","Action":"private-data","Code":"ok"}]')
    $events=@(Read-LauncherEvents $root)
    Assert-Equal 1 $events.Count
    Assert-True (($events|ConvertTo-Json) -notmatch 'private-data|Secret')
}
Test-Case 'Shortcut creation/update is idempotent and unrelated shortcuts are preserved' {
    $root=New-TestRoot;$shortcut=Join-Path $root 'Launcher.lnk';$dest=Join-Path $root 'Installed'
    Assert-Equal 'Created' (New-LauncherShortcut $dest $shortcut)
    Assert-Equal 'Unchanged' (New-LauncherShortcut $dest $shortcut)
    $shell=New-Object -ComObject WScript.Shell;$link=$shell.CreateShortcut($shortcut)
    $link.Arguments='unrelated owner shortcut';$link.Save()
    Assert-Equal 'PreservedOther' (New-LauncherShortcut $dest $shortcut)
    Remove-LauncherShortcut $dest $shortcut
    Assert-True (Test-Path $shortcut)
    [IO.File]::Delete($shortcut)
    $null=New-LauncherShortcut $dest $shortcut
    Remove-LauncherShortcut $dest $shortcut
    Assert-True (!(Test-Path $shortcut))
}
Complete-Tests
