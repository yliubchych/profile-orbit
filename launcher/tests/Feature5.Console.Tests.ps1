. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Windows.ps1"
Test-Case 'UI bootstrap starts a console-free STA process and preserves a custom data root' {
    $root=New-TestRoot
    $worker=Join-Path $root 'mock launcher.ps1'
    $data=(Join-Path $root 'custom data')+'\'
    $null=New-Item -ItemType Directory $data
    $source=@'
param([switch]$Detached,[string]$DataRoot)
Add-Type 'using System; using System.Runtime.InteropServices; public class ConsoleProbe { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); }'
@{Detached=[bool]$Detached;DataRoot=$DataRoot;Console=[ConsoleProbe]::GetConsoleWindow().ToInt64();Apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString()} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $DataRoot 'result.json')
'@
    [IO.File]::WriteAllText($worker,$source)
    $process=[Diagnostics.Process]::Start((New-LauncherUIStartInfo $worker $data))
    try {
        Assert-True $process.WaitForExit(15000)
        Assert-Equal 0 $process.ExitCode
    } finally {if(!$process.HasExited){$process.Kill()};$process.Dispose()}
    $result=Get-Content -Raw (Join-Path $data 'result.json') | ConvertFrom-Json
    Assert-True $result.Detached
    Assert-Equal $data $result.DataRoot
    Assert-Equal 0 $result.Console
    Assert-Equal 'STA' $result.Apartment
}
Complete-Tests
