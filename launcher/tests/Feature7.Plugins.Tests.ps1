. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'Plugin entry link opens only the official directory inside the app browser' {
    $link=New-LauncherPluginsLink
    Assert-Equal 'codex://browser?url=https%3A%2F%2Fchatgpt.com%2Fplugins' $link
    $start=New-ProfileStartInfo 'C:\App\ChatGPT.exe' 'C:\selected\desktop' 'C:\selected\codex' $link
    Assert-Equal ('--user-data-dir="C:\selected\desktop" "'+$link+'"') $start.Arguments
    Assert-Equal $false $start.UseShellExecute
    foreach($bad in @('codex://browser?url=https%3A%2F%2Fevil.example','codex://browser?url=https%3A%2F%2Fchatgpt.com%2Fplugins&extra=bad','codex://browser?url=javascript%3Aalert(1)')){
        Assert-Throws {New-ProfileStartInfo 'C:\App\ChatGPT.exe' 'C:\selected\desktop' 'C:\selected\codex' $bad}
    }
}
Test-Case 'Plugin action starts or focuses the requested profile and dispatches directly to its browser' {
    $root=New-TestRoot;$a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $script:Opened=$null;$script:Sent=$null
    function Start-CodexProfile($Name){$script:Opened=$Name}
    function Find-CodexApp {return 'mock.exe'}
    function Invoke-ProfileLaunch($App,$Data,$Codex,$DeepLink){$script:Sent=@($App,$Data,$Codex,$DeepLink)}
    Invoke-LauncherPlugins $root $b.Id
    Assert-Equal $b.Id $script:Opened
    Assert-Equal @('mock.exe',(Join-Path $root ($b.Id+'/desktop')),(Join-Path $root ($b.Id+'/codex')),(New-LauncherPluginsLink)) $script:Sent
    Assert-Equal 0 @(Get-ChildItem -LiteralPath $root -Directory).Count
    Assert-Throws {Invoke-LauncherPlugins $root ('f'*32)} '*not found*'
}
Complete-Tests
