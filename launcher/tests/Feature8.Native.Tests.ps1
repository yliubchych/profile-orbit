. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Release.ps1"
. "$PSScriptRoot/../Updates.ps1"
Test-Case 'Separate updater installs verified package and restarts with the same custom data root' {
    $root=New-TestRoot;$source=Join-Path $root 'source';$null=New-Item -ItemType Directory $source
    foreach($file in Get-LauncherReleaseFiles){Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/.." $file) -Destination (Join-Path $source $file)}
    [IO.File]::WriteAllText((Join-Path $source 'VERSION'),'0.1.0-beta.3')
    # Replacement launcher writes only a synthetic marker; never opens a signed-in app.
    $mock='param([string]$DataRoot) [IO.File]::WriteAllText((Join-Path $DataRoot "restarted.txt"),$DataRoot)'
    [IO.File]::WriteAllText((Join-Path $source 'Launcher.ps1'),$mock)
    $dest=Join-Path $root 'installed copy';Install-Launcher $source $dest
    $data=Join-Path $root 'custom profile root';$null=New-Item -ItemType Directory $data
    [IO.File]::WriteAllText((Join-Path $data 'sentinel'),'synthetic')
    [IO.File]::WriteAllText((Join-Path $source 'VERSION'),'0.1.0-beta.4')
    $archive=New-LauncherPackage $source $root;$hash=(Get-FileHash $archive).Hash
    $request=Join-Path $root 'request.json'
    $job=@{Destination=$dest;DataRoot=$data;Archive=$archive;Sha256=$hash;Version='0.1.0-beta.4';ParentId=2147483647;ParentTicks=0}
    [IO.File]::WriteAllText($request,($job|ConvertTo-Json))
    $info=New-LauncherUpdateStartInfo "$PSScriptRoot/../UpdateWorker.ps1" ('-Request "'+$request+'"')
    $process=[Diagnostics.Process]::Start($info)
    try{Assert-True $process.WaitForExit(15000);Assert-Equal 0 $process.ExitCode}finally{if(!$process.HasExited){$process.Kill()};$process.Dispose()}
    $limit=[DateTime]::UtcNow.AddSeconds(8)
    while(!(Test-Path (Join-Path $data 'restarted.txt')) -and [DateTime]::UtcNow -lt $limit){Start-Sleep -Milliseconds 100}
    Assert-Equal $data ([IO.File]::ReadAllText((Join-Path $data 'restarted.txt')))
    Assert-Equal 'synthetic' ([IO.File]::ReadAllText((Join-Path $data 'sentinel')))
    Assert-Equal '0.1.0-beta.4' ([IO.File]::ReadAllText((Join-Path $dest 'VERSION')))
    $null=Read-InstallManifest $dest
}
Test-Case 'Updater helper environment drops account and agent context' {
    Assert-Equal '"D:\\"' (ConvertTo-LauncherProcessArgument 'D:\')
    Assert-Throws {ConvertTo-LauncherProcessArgument 'D:\bad"path'}
    $env:CODEX_HOME='synthetic-account';$env:OPENAI_API_KEY='synthetic-secret'
    try{
        $info=New-LauncherUpdateStartInfo 'C:\synthetic\UpdateWorker.ps1' '-Request "C:\synthetic\request.json"'
        Assert-Equal $null $info.EnvironmentVariables['CODEX_HOME']
        Assert-Equal $null $info.EnvironmentVariables['OPENAI_API_KEY']
        Assert-Equal $false $info.UseShellExecute
        Assert-True $info.CreateNoWindow
    }finally{Remove-Item Env:CODEX_HOME,Env:OPENAI_API_KEY -ErrorAction SilentlyContinue}
}
Complete-Tests
