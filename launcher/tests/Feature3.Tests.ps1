. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'Save project shortcut under its selected profile only' {
    $root=New-TestRoot;$folder=New-TestRoot
    $a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $project=Add-LauncherProject $root $a.Id 'Client website' $folder
    Assert-Equal 1 @(Get-LauncherProjects $root $a.Id).Count
    Assert-Equal 0 @(Get-LauncherProjects $root $b.Id).Count
    Assert-Equal ([IO.Path]::GetFullPath($folder)) $project.Path
    $null=Update-LauncherProfile $root $a.Id 'Renamed' '#AFCBFF'
    Assert-Equal $project.Id @(Get-LauncherProjects $root $a.Id)[0].Id
}
Test-Case 'Reject missing folders, relative paths, files and duplicate shortcuts' {
    $root=New-TestRoot;$folder=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC'
    Assert-Throws { Add-LauncherProject $root $p.Id 'Missing' (Join-Path $folder 'missing') }
    Assert-Throws { Add-LauncherProject $root $p.Id 'Relative' '.' }
    $file=Join-Path $folder 'file.txt';[IO.File]::WriteAllText($file,'test')
    Assert-Throws { Add-LauncherProject $root $p.Id 'File' $file }
    $null=Add-LauncherProject $root $p.Id 'Existing' $folder
    Assert-Throws { Add-LauncherProject $root $p.Id 'Duplicate' $folder } '*already*'
}
Test-Case 'Removing a shortcut preserves its folder and other profiles' {
    $root=New-TestRoot;$folder=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC'
    $item=Add-LauncherProject $root $p.Id 'Sample' $folder
    Remove-LauncherProject $root $p.Id $item.Id
    Assert-Equal 0 @(Get-LauncherProjects $root $p.Id).Count
    Assert-True (Test-Path $folder -PathType Container)
}
Test-Case 'Encode the documented workspace path with no prompt or shell injection' {
    $folder=Join-Path (New-TestRoot) 'project & details #1'
    $null=New-Item -ItemType Directory $folder
    $link=New-ProjectDeepLink $folder
    Assert-True ($link -like 'codex://threads/new?path=*')
    Assert-Equal $folder ([Uri]::UnescapeDataString(($link -split '\?path=',2)[1]))
    Assert-True (!$link.Contains('&'))
    Assert-True (!$link.Contains('prompt='))
}
Test-Case 'Project activation is delivered directly to the selected profile, not the global URL handler' {
    $root=New-TestRoot;$folder=New-TestRoot;$a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $item=Add-LauncherProject $root $a.Id 'Site' $folder
    $script:Started='';$script:Invocation=$null
    function Start-CodexProfile($Name){$script:Started=$Name;return 123}
    function Find-CodexApp {return 'mock.exe'}
    function Invoke-ProfileLaunch($App,$Data,$Codex,$DeepLink){$script:Invocation=@($Data,$Codex,$DeepLink)}
    $profileRoot=$root
    Invoke-LauncherProject $root $a.Id $item.Id
    Assert-Equal $a.Id $script:Started
    Assert-Equal (Join-Path (Join-Path $root $a.Id) 'desktop') $script:Invocation[0]
    Assert-Equal (Join-Path (Join-Path $root $a.Id) 'codex') $script:Invocation[1]
    Assert-Equal (New-ProjectDeepLink $folder) $script:Invocation[2]
}
Test-Case 'Deleted project folder is reported before any profile is opened' {
    $root=New-TestRoot;$folder=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC'
    $item=Add-LauncherProject $root $p.Id 'Moved' $folder
    # Empty synthetic folder, not a user project.
    [IO.Directory]::Delete($folder)
    function Start-CodexProfile { throw 'Must not launch for a missing folder' }
    Assert-Throws { Invoke-LauncherProject $root $p.Id $item.Id } '*folder*'
}
Complete-Tests
