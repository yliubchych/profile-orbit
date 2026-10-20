. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"

Test-Case 'Profile names accept the boundary length and normalize whitespace and color' {
    $root=New-TestRoot
    $name='N'*60
    $p=Add-LauncherProfile $root ("  $name  ") '#aBc123'
    Assert-Equal $name (Get-LauncherProfile $root $p.Id).Name
    Assert-Equal '#ABC123' (Get-LauncherProfile $root $p.Id).Color
}
Test-Case 'Invalid names and colors leave existing metadata byte-for-byte unchanged' {
    $root=New-TestRoot
    $p=Add-LauncherProfile $root 'Original' '#9BE4CC'
    $path=Join-Path $root 'launcher.json';$before=[IO.File]::ReadAllText($path)
    foreach($name in @('',('N'*61),"line`nbreak","tab`tname")) {
        Assert-Throws {Update-LauncherProfile $root $p.Id $name '#9BE4CC'} '*profile name*'
        Assert-Equal $before ([IO.File]::ReadAllText($path))
    }
    foreach($color in @('#12345','#1234567','123456','#GG0000')) {
        Assert-Throws {Update-LauncherProfile $root $p.Id 'Changed' $color} '*color*'
        Assert-Equal $before ([IO.File]::ReadAllText($path))
    }
}
Test-Case 'Duplicate rename and unknown-profile edit preserve both profiles and metadata' {
    $root=New-TestRoot
    $a=Add-LauncherProfile $root 'Work' '#9BE4CC'
    $null=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $path=Join-Path $root 'launcher.json';$before=[IO.File]::ReadAllText($path)
    Assert-Throws {Update-LauncherProfile $root $a.Id ' HOME ' '#AFCBFF'} '*already exists*'
    Assert-Throws {Update-LauncherProfile $root ('a'*32) 'New' '#AFCBFF'} '*not found*'
    Assert-Equal $before ([IO.File]::ReadAllText($path))
}
Test-Case 'Invalid stored profile lists are rejected without rewriting their contents' {
    $root=New-TestRoot;$path=Join-Path $root 'launcher.json'
    $a=[pscustomobject]@{Id='a'*32;Name='Work';Color='#9BE4CC'}
    foreach($profiles in @(
        @($a,[pscustomobject]@{Id=$a.Id;Name='Other';Color='#AFCBFF'}),
        @($a,[pscustomobject]@{Id='b'*32;Name=' work ';Color='#AFCBFF'}),
        @([pscustomobject]@{Id='A'*32;Name='Work';Color='#9BE4CC'}),
        @([pscustomobject]@{Id='a'*32;Name='Work';Color='invalid'})
    )) {
        $json=@{schemaVersion=1;profiles=@($profiles)}|ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText($path,$json)
        Assert-Throws {Read-LauncherStore $root}
        Assert-Equal $json ([IO.File]::ReadAllText($path))
    }
    $json='{"schemaVersion":1}'
    [IO.File]::WriteAllText($path,$json)
    Assert-Throws {Read-LauncherStore $root} '*profile list*'
    Assert-Equal $json ([IO.File]::ReadAllText($path))
}
Test-Case 'Repeated atomic metadata replacement leaves no temporary or backup files' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'First' '#9BE4CC'
    1..3 | ForEach-Object {$null=Update-LauncherProfile $root $p.Id "Revision $_" '#AFCBFF'}
    Assert-Equal 'Revision 3' (Get-LauncherProfile $root $p.Id).Name
    Assert-Equal @('launcher.json') @(Get-ChildItem -LiteralPath $root -File | ForEach-Object {$_.Name})
}
Test-Case 'Operation exceptions release the named mutex for another thread' {
    $name=Get-LauncherLockName (New-TestRoot)
    Assert-Throws {Invoke-LauncherLock $name {throw 'synthetic failure'}} '*synthetic failure*'
    $job=[PowerShell]::Create()
    try {
        $null=$job.AddScript({param($lockName)
            $mutex=New-Object Threading.Mutex($false,$lockName)
            try {$owned=$mutex.WaitOne(1000);if($owned){$mutex.ReleaseMutex()};return $owned}
            finally {$mutex.Dispose()}
        }).AddArgument($name)
        Assert-Equal $true @($job.Invoke())[0]
        Assert-Equal 0 $job.Streams.Error.Count
    } finally {$job.Dispose()}
}
Complete-Tests
