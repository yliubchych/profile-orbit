. "$PSScriptRoot/TestHarness.ps1"
$core = Join-Path $PSScriptRoot '../Core.ps1'
if (Test-Path $core) { . $core }
Test-Case 'Fresh setup starts empty and creates no account directories' {
    $root = New-TestRoot
    Assert-Equal 0 @(Get-LauncherProfiles $root).Count
    Assert-Equal 0 @(Get-ChildItem $root -Directory).Count
}
Test-Case 'Create profiles, persist Unicode names and chosen color' {
    $root = New-TestRoot
    $p = Add-LauncherProfile $root 'Work team' '#AFCBFF'
    $q = Add-LauncherProfile $root 'Особисте' '#9BE4CC'
    Assert-Equal 2 @(Get-LauncherProfiles $root).Count
    Assert-Equal 'Work team' (Get-LauncherProfile $root $p.Id).Name
    Assert-Equal 'Особисте' (Get-LauncherProfile $root $q.Id).Name
    Assert-Equal '#AFCBFF' (Get-LauncherProfile $root $p.Id).Color
    Assert-True ($p.Id -match '^[a-f0-9]{32}$')
    Assert-True ($p.Id -ne $q.Id)
}
Test-Case 'Rename/recolor preserve identity, other profile and account files' {
    $root = New-TestRoot
    $p = Add-LauncherProfile $root 'Work' '#AFCBFF'
    $q = Add-LauncherProfile $root 'Personal' '#9BE4CC'
    $folder = Join-Path $root ($p.Id + '/codex')
    $null = New-Item -ItemType Directory $folder -Force
    [IO.File]::WriteAllText((Join-Path $folder 'sentinel.txt'),'test-only-marker')
    $null = Update-LauncherProfile $root $p.Id 'Client A' '#E6C38A'
    Assert-Equal $p.Id (Get-LauncherProfile $root $p.Id).Id
    Assert-Equal 'Client A' (Get-LauncherProfile $root $p.Id).Name
    Assert-Equal '#E6C38A' (Get-LauncherProfile $root $p.Id).Color
    Assert-Equal 'test-only-marker' ([IO.File]::ReadAllText((Join-Path $folder 'sentinel.txt')))
    Assert-Equal 'Personal' (Get-LauncherProfile $root $q.Id).Name
}
Test-Case 'Reject blank names, duplicate names and invalid colors without changing store' {
    $root = New-TestRoot
    $p = Add-LauncherProfile $root 'Work' '#AFCBFF'
    Assert-Throws { Add-LauncherProfile $root '  ' '#AFCBFF' }
    Assert-Throws { Add-LauncherProfile $root ' work ' '#AFCBFF' } '*already exists*'
    Assert-Throws { Add-LauncherProfile $root 'New' 'red;command' }
    Assert-Equal 1 @(Get-LauncherProfiles $root).Count
}
Test-Case 'Legacy PBX and Personal folders are adopted without copying data' {
    $root = New-TestRoot
    $null = New-Item -ItemType Directory (Join-Path $root 'PBX'),(Join-Path $root 'Personal')
    $items = @(Get-LauncherProfiles $root)
    Assert-Equal 2 $items.Count
    Assert-Equal 'PBX' (Get-LauncherProfile $root 'PBX').Id
    Assert-Equal 'Personal' (Get-LauncherProfile $root 'Personal').Id
    Assert-Equal 2 @(Get-ChildItem $root -Directory).Count
}
Test-Case 'Corrupt metadata is reported and never reset' {
    $root = New-TestRoot
    $path = Join-Path $root 'launcher.json'
    [IO.File]::WriteAllText($path,'broken-json')
    Assert-Throws { Get-LauncherProfiles $root } '*metadata*'
    Assert-Equal 'broken-json' ([IO.File]::ReadAllText($path))
}
Test-Case 'Unknown schema and traversal identifiers are rejected' {
    $root = New-TestRoot
    [IO.File]::WriteAllText((Join-Path $root 'launcher.json'),'{"schemaVersion":999,"profiles":[]}')
    Assert-Throws { Get-LauncherProfiles $root } '*schema*'
    [IO.File]::WriteAllText((Join-Path $root 'launcher.json'),'{"schemaVersion":1,"profiles":[{"Id":"../escape","Name":"Test","Color":"#AFCBFF"}]}')
    Assert-Throws { Get-LauncherProfiles $root } '*identifier*'
}
Test-Case 'Lookup and edits reject unknown identity' {
    $root = New-TestRoot
    $null = Add-LauncherProfile $root 'Work' '#AFCBFF'
    Assert-Throws { Update-LauncherProfile $root '../escape' 'X' '#AFCBFF' }
    Assert-Throws { Get-LauncherProfile $root ('a'*32) } '*not found*'
}
Complete-Tests
