. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'Windows handler command delivers an opaque callback as one positional argument' {
    $root=New-TestRoot;$capture=Join-Path $root 'capture arguments.ps1';$received=Join-Path $root 'received.json'
    [IO.File]::WriteAllText($capture,'[IO.File]::WriteAllText((Join-Path $PSScriptRoot ''received.json''),(ConvertTo-Json -InputObject @($args)))')
    $link='codex://connector/oauth_callback?code=test%2B%2522&state=x%2Fy&returnTo=%2Fplugins'
    $command=(Get-CallbackHandlerCommand $root $capture).Replace('%1',$link)
    $end=$command.IndexOf('" ',1)
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$command.Substring(1,$end-1);$start.Arguments=$command.Substring($end+2)
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $process=[Diagnostics.Process]::Start($start)
    try {Assert-True ($process.WaitForExit(10000));Assert-Equal 0 $process.ExitCode}finally{$process.Dispose()}
    $actual=[IO.File]::ReadAllText($received)|ConvertFrom-Json
    Assert-Equal @($root,$link) @($actual)
}
Test-Case 'Actual desktop subprocess receives callback once with only the selected profile environment' {
    $root=New-TestRoot;$app=Join-Path $root 'Mock desktop.exe'
    Add-Type -OutputAssembly $app -OutputType ConsoleApplication -TypeDefinition @'
using System;using System.IO;using System.Collections.Generic;
public static class CallbackCapture {
 public static void Main(string[] args) {
  var lines=new List<string>(args);
  lines.Add(Environment.GetEnvironmentVariable("CODEX_HOME") ?? "");
  lines.Add(Environment.GetEnvironmentVariable("CODEX_ELECTRON_USER_DATA_PATH") ?? "");
  File.WriteAllLines(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"received.txt"),lines.ToArray());
 }
}
'@
    $link='codex://connector/oauth_callback?code=test%2Bvalue&state=unchanged%2522'
    $data=Join-Path $root 'profile data\desktop';$codex=Join-Path $root 'profile data\codex'
    $start=New-ProfileStartInfo $app $data $codex $link
    $process=[Diagnostics.Process]::Start($start)
    try {Assert-True ($process.WaitForExit(10000));Assert-Equal 0 $process.ExitCode}finally{$process.Dispose()}
    Assert-Equal @(('--user-data-dir='+$data),$link,$codex,$data) @([IO.File]::ReadAllLines((Join-Path $root 'received.txt')))
}
Complete-Tests
