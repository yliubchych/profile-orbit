# Repository updates use public GitHub Releases, never execute a branch checkout.
function ConvertTo-LauncherVersion([string]$Value) {
    if($Value -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9a-z-]+(?:\.[0-9a-z-]+)*))?$'){throw 'Invalid update version.'}
    $core=($Value -split '-',2)[0].Split('.')
    $pre=@();if($Value.Contains('-')){$pre=@(($Value -split '-',2)[1].Split('.'))}
    foreach($part in $pre){if($part -match '^0[0-9]+$'){throw 'Invalid update version.'}}
    [pscustomobject]@{Core=$core;Pre=$pre}
}
function Compare-LauncherVersion([string]$Left,[string]$Right) {
    $a=ConvertTo-LauncherVersion $Left;$b=ConvertTo-LauncherVersion $Right
    for($i=0;$i -lt 3;$i++){
        if($a.Core[$i].Length -ne $b.Core[$i].Length){return [Math]::Sign($a.Core[$i].Length-$b.Core[$i].Length)}
        $cmp=[string]::CompareOrdinal($a.Core[$i],$b.Core[$i]);if($cmp){return [Math]::Sign($cmp)}
    }
    if(!$a.Pre.Count -and !$b.Pre.Count){return 0}
    if(!$a.Pre.Count){return 1};if(!$b.Pre.Count){return -1}
    for($i=0;$i -lt [Math]::Min($a.Pre.Count,$b.Pre.Count);$i++){
        $x=$a.Pre[$i];$y=$b.Pre[$i];$xn=$x -match '^[0-9]+$';$yn=$y -match '^[0-9]+$'
        if($xn -and !$yn){return -1};if(!$xn -and $yn){return 1}
        if($xn -and $yn -and $x.Length -ne $y.Length){return [Math]::Sign($x.Length-$y.Length)}
        $cmp=[string]::CompareOrdinal($x,$y);if($cmp){return [Math]::Sign($cmp)}
    }
    return [Math]::Sign($a.Pre.Count-$b.Pre.Count)
}
function Select-LauncherUpdate($Releases,[string]$CurrentVersion) {
    $current=ConvertTo-LauncherVersion $CurrentVersion;$best=$null
    foreach($release in @($Releases)){
        if($release.draft -or (!$current.Pre.Count -and $release.prerelease)){continue}
        $version=[string]$release.tag_name
        if($version.StartsWith('v')){$version=$version.Substring(1)}
        try{
            $parsed=ConvertTo-LauncherVersion $version
            if(!$current.Pre.Count -and $parsed.Pre.Count){continue}
            if((Compare-LauncherVersion $version $CurrentVersion) -le 0){continue}
            if($best -and (Compare-LauncherVersion $version $best.Version) -le 0){continue}
        }catch{continue}
        $name="ProfileLauncher-$version.zip"
        $assets=@($release.assets|Where-Object {$_.name -ceq $name -and $_.state -eq 'uploaded'})
        if($assets.Count -ne 1){continue}
        $asset=$assets[0]
        $expected="https://github.com/yliubchych/profile-orbit/releases/download/$($release.tag_name)/$name"
        if($asset.browser_download_url -cne $expected -or $asset.digest -cnotmatch '^sha256:[a-fA-F0-9]{64}$' -or $asset.size -le 0 -or $asset.size -gt 20MB){continue}
        $best=[pscustomobject]@{Version=$version;Url=$expected;Sha256=$asset.digest.Substring(7);Size=[long]$asset.size;ReleaseUrl="https://github.com/yliubchych/profile-orbit/releases/tag/$($release.tag_name)"}
    }
    return $best
}
function Get-LauncherUpdate([string]$CurrentVersion) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $headers=@{Accept='application/vnd.github+json';'User-Agent'='ProfileLauncher';'X-GitHub-Api-Version'='2026-03-10'}
    $releases=@()
    # Bound requests; include prereleases, which /releases/latest intentionally excludes.
    for($page=1;$page -le 3;$page++){
        try{$batch=@(Invoke-RestMethod -Uri "https://api.github.com/repos/yliubchych/profile-orbit/releases?per_page=100&page=$page" -Headers $headers -TimeoutSec 15)}
        catch{throw 'Could not check GitHub releases. Check your connection and try again. The repository must be public; rate limits can also delay checks.'}
        $releases+=@($batch)
        if($batch.Count -lt 100){break}
    }
    Select-LauncherUpdate $releases $CurrentVersion
}
function Assert-LauncherUpdateTarget([string]$Destination) {
    $dest=Assert-InstallDirectory $Destination
    if(!(Test-Path -LiteralPath (Join-Path $dest 'installation.json'))){throw 'Updates require an installed copy. Run Install.cmd once, then open the installed launcher.'}
    $manifest=Read-InstallManifest $dest
    foreach($file in $manifest.Files){
        $path=Join-Path $dest $file
        if(!(Test-Path -LiteralPath $path -PathType Leaf) -or ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $manifest.Hashes.$file){throw 'An installed file is missing or edited. Preserve your changes and use the manual installer.'}
    }
}
function Expand-LauncherUpdate([string]$Archive,[string]$Destination,[string]$Sha256,[string]$Version) {
    if($Sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ine $Sha256){throw 'Update archive checksum mismatch. Nothing was installed.'}
    $null=ConvertTo-LauncherVersion $Version
    if(Test-Path -LiteralPath $Destination){throw 'Update staging folder already exists.'}
    $null=Assert-InstallDirectory $Destination
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try{
        $allowed=@(Get-LauncherReleaseFiles)+@('package-manifest.json');$seen=@{};$total=0L
        foreach($entry in $zip.Entries){
            if($allowed -cnotcontains $entry.FullName -or $seen.ContainsKey($entry.FullName)){throw 'Unexpected or duplicate update archive entry.'}
            $seen[$entry.FullName]=$true;$total+=$entry.Length
            if($entry.Length -gt 10MB -or $total -gt 40MB){throw 'Update archive exceeds the size limit.'}
        }
        if($seen.Count -ne $allowed.Count){throw 'Incomplete update archive.'}
        $null=New-Item -ItemType Directory -Path $Destination
        foreach($entry in $zip.Entries){
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $Destination $entry.FullName),$false)
        }
    }finally{$zip.Dispose()}
    # Parse and hash all scripts, but never dot-source downloaded code before validation.
    Assert-ReleaseSource $Destination
    $manifest=[IO.File]::ReadAllText((Join-Path $Destination 'package-manifest.json'))|ConvertFrom-Json
    $actual=([IO.File]::ReadAllText((Join-Path $Destination 'VERSION'))).Trim()
    if($manifest.Version -cne $Version -or $actual -cne $Version){throw 'Update package version mismatch.'}
    return [IO.Path]::GetFullPath($Destination)
}
function Save-LauncherUpdate($Update,[string]$CacheRoot) {
    # Revalidate the candidate even when called independently from the UI.
    $tag='v'+$Update.Version
    $release=[pscustomobject]@{tag_name=$tag;draft=$false;prerelease=$true;assets=@([pscustomobject]@{name="ProfileLauncher-$($Update.Version).zip";state='uploaded';size=$Update.Size;digest=('sha256:'+$Update.Sha256);browser_download_url=$Update.Url})}
    # Support both v-prefixed and bare semantic tags.
    if($Update.Url -ceq "https://github.com/yliubchych/profile-orbit/releases/download/$($Update.Version)/ProfileLauncher-$($Update.Version).zip"){$release.tag_name=$Update.Version}
    if(!(Select-LauncherUpdate @($release) '0.0.0-0')){throw 'Invalid update download source.'}
    $null=Assert-InstallDirectory $CacheRoot
    $stage=Join-Path $CacheRoot ([guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $stage -Force
    $archive=Join-Path $stage 'update.zip'
    try{
        [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $Update.Url -OutFile $archive -TimeoutSec 120 -Headers @{'User-Agent'='ProfileLauncher'} | Out-Null
        if((Get-Item -LiteralPath $archive).Length -ne $Update.Size){throw 'Update download size mismatch.'}
        $source=Expand-LauncherUpdate $archive (Join-Path $stage 'package') $Update.Sha256 $Update.Version
        return [pscustomobject]@{Stage=$stage;Source=$source;Archive=$archive;Sha256=$Update.Sha256;Version=$Update.Version}
    }catch{throw 'Could not download or verify the update. Nothing was installed. Try again or use the manual release ZIP.'}
}
function ConvertTo-LauncherProcessArgument([string]$Value) {
    if($Value.Contains('"') -or $Value -match '[\r\n]'){throw 'Invalid update process argument.'}
    # Windows doubles trailing backslashes immediately before a closing quote.
    return '"'+[regex]::Replace($Value,'(\\+)$','$1$1')+'"'
}
function New-LauncherUpdateStartInfo([string]$Script,[string]$Arguments) {
    if($Script.Contains('"') -or $Script -match '[\r\n]'){throw 'Invalid update helper path.'}
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -ExecutionPolicy Bypass -STA -File '+(ConvertTo-LauncherProcessArgument $Script)+' '+$Arguments
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle='Hidden'
    foreach($key in @($info.EnvironmentVariables.Keys)){if($key -match '^(CODEX_|OPENAI_)'){$info.EnvironmentVariables.Remove($key)}}
    return $info
}
function Start-LauncherUpdateInstall($Prepared,[string]$Destination,[string]$DataRoot) {
    Assert-LauncherUpdateTarget $Destination
    $stage=Assert-InstallDirectory $Prepared.Stage
    $helper=Join-Path $stage 'helper';$null=New-Item -ItemType Directory -Path $helper
    # Execute this installed version's updater, not a downloaded installer.
    foreach($file in @('Core.ps1','Release.ps1','CallbackRouting.ps1','Updates.ps1','UpdateWorker.ps1')){
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $helper $file)
    }
    $request=Join-Path $stage 'request.json'
    $process=Get-Process -Id $PID
    $payload=@{Destination=$Destination;DataRoot=$DataRoot;Archive=$Prepared.Archive;Sha256=$Prepared.Sha256;Version=$Prepared.Version;ParentId=$PID;ParentTicks=$process.StartTime.ToUniversalTime().Ticks}
    [IO.File]::WriteAllText($request,($payload|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    if($request.Contains('"')){throw 'Invalid update request path.'}
    $info=New-LauncherUpdateStartInfo (Join-Path $helper 'UpdateWorker.ps1') ('-Request "'+$request+'"')
    $child=[Diagnostics.Process]::Start($info)
    if(!$child){throw 'Could not start the update installer.'}
    $child.Dispose()
}
