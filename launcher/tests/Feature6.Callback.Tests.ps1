. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'Callback validation preserves encoded authorization bytes and rejects command injection' {
    $link='codex://connector/oauth_callback?code=test%2B%2522&state=test%2Fstate&returnTo=%2Fplugins'
    Assert-Equal $link (Assert-ConnectorCallbackLink $link)
    foreach($bad in @('https://example.com/','codex://connector.evil/oauth_callback?state=x','codex://connector/oauth_callback/extra?state=x','codex://connector/oauth_callback',"codex://connector/oauth_callback?code=a`" -File evil", "codex://connector/oauth_callback?code=a`nb",('codex://connector/oauth_callback?code='+('a'*17000)))) {
        Assert-Throws {Assert-ConnectorCallbackLink $bad}
    }
    $start=New-ProfileStartInfo 'C:\App\ChatGPT.exe' 'C:\Profile\desktop' 'C:\Profile\codex' $link
    Assert-True ($start.Arguments.EndsWith(('"'+$link+'"')))
    Assert-Equal $false $start.UseShellExecute
}
Test-Case 'Callback selection targets one rechecked running profile with unchanged authorization state' {
    $root=New-TestRoot;$a=Add-LauncherProfile $root 'First' '#9BE4CC';$b=Add-LauncherProfile $root 'Second' '#AFCBFF'
    $script:Chosen=$b.Id;$script:Sent=$null;$script:Seen=$null
    function Get-ProfileProcess($DataPath){[pscustomobject]@{ProcessId=42;CreationDate='same'}}
    function Select-LauncherCallbackTarget($Targets){$script:Seen=@($Targets);return $script:Chosen}
    function Find-CodexApp {return 'mock.exe'}
    function Invoke-ProfileLaunch($App,$Data,$Codex,$DeepLink){$script:Sent=@($App,$Data,$Codex,$DeepLink)}
    $link='codex://connector/oauth_callback?code=synthetic&state=unchanged%2Bvalue'
    Invoke-LauncherCallback $root $link
    Assert-Equal 3 $script:Seen.Count
    Assert-Equal @('mock.exe',(Join-Path $root ($b.Id+'/desktop')),(Join-Path $root ($b.Id+'/codex')),$link) $script:Sent
    Assert-Equal 0 @(Get-ChildItem $root -Directory).Count
    Assert-True (!(Test-Path (Join-Path $root 'events.json')))
}
Test-Case 'Cancel, unknown choice, ambiguous processes and changed process identity never receive a callback' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'First' '#9BE4CC';$link='codex://connector/oauth_callback?state=synthetic'
    function Invoke-ProfileLaunch {throw 'Must not forward'}
    function Invoke-DefaultCallback {throw 'Must not forward'}
    function Get-ProfileProcess {[pscustomobject]@{ProcessId=42;CreationDate='same'}}
    function Select-LauncherCallbackTarget {return $null}
    Invoke-LauncherCallback $root $link
    function Select-LauncherCallbackTarget {return 'unknown'}
    Assert-Throws {Invoke-LauncherCallback $root $link} '*selection*'
    function Select-LauncherCallbackTarget {return $p.Id}
    $script:Calls=0
    function Get-ProfileProcess {$script:Calls++;[pscustomobject]@{ProcessId=42;CreationDate=[string]$script:Calls}}
    Assert-Throws {Invoke-LauncherCallback $root $link} '*changed*'
    function Get-ProfileProcess {@([pscustomobject]@{ProcessId=42;CreationDate='same'},[pscustomobject]@{ProcessId=43;CreationDate='same'})}
    Assert-Throws {Invoke-LauncherCallback $root $link} '*selection*'
}
Test-Case 'Default app remains an explicit callback target and normal deep links keep their default route' {
    $script:Sent=$null
    function Invoke-DefaultCallback($Link){$script:Sent=$Link}
    function Select-LauncherCallbackTarget {return 'default'}
    $root=New-TestRoot;$link='codex://connector/oauth_callback?state=synthetic'
    Invoke-LauncherCallback $root $link
    Assert-Equal $link $script:Sent
    $script:Sent=$null
    Invoke-LauncherCallback $root 'codex://settings'
    Assert-Equal 'codex://settings' $script:Sent
    Assert-Throws {Invoke-LauncherCallback $root 'file:///C:/private'}
}
Test-Case 'Default process launch drops inherited profile and agent context' {
    $old=$env:CODEX_HOME
    try {
        $env:CODEX_HOME='synthetic-profile'
        $start=New-DefaultCallbackStartInfo 'C:\App\ChatGPT.exe' 'codex://settings'
        Assert-Equal $null $start.EnvironmentVariables['CODEX_HOME']
        Assert-Equal $null $start.EnvironmentVariables['CODEX_ELECTRON_USER_DATA_PATH']
        Assert-Equal '"codex://settings"' $start.Arguments
        Assert-Equal $false $start.UseShellExecute
    } finally {$env:CODEX_HOME=$old}
}
Complete-Tests
