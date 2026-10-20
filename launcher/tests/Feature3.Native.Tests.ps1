. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'Actual subprocess receives one encoded project URI and isolated profile environment' {
    $root=New-TestRoot;$app=Join-Path $root 'Mock desktop.exe'
    Add-Type -OutputAssembly $app -OutputType ConsoleApplication -TypeDefinition @'
using System;using System.IO;using System.Collections.Generic;
public static class MockDesktop {
 public static void Main(string[] args) {
  var lines=new List<string>(args);
  lines.Add(Environment.GetEnvironmentVariable("CODEX_HOME") ?? "");
  lines.Add(Environment.GetEnvironmentVariable("CODEX_ELECTRON_USER_DATA_PATH") ?? "");
  lines.Add(Environment.GetEnvironmentVariable("OPENAI_API_KEY") ?? "");
  File.WriteAllLines(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"received.txt"),lines.ToArray());
 }
}
'@
    $data=Join-Path $root 'profile data\desktop';$codex=Join-Path $root 'profile data\codex'
    $link=New-ProjectDeepLink $root
    $env:OPENAI_API_KEY='test-only-secret'
    try {
        Invoke-ProfileLaunch $app $data $codex $link
        $received=Join-Path $root 'received.txt'
        for($n=0;$n -lt 60 -and !(Test-Path $received);$n++){Start-Sleep -Milliseconds 100}
        Assert-True (Test-Path $received)
        $lines=[IO.File]::ReadAllLines($received)
        Assert-Equal 5 $lines.Count
        Assert-Equal ('--user-data-dir='+$data) $lines[0]
        Assert-Equal $link $lines[1]
        Assert-Equal $codex $lines[2];Assert-Equal $data $lines[3];Assert-Equal '' $lines[4]
    } finally {Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue}
}
Complete-Tests
