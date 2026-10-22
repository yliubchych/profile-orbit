. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Release.ps1"
if(Test-Path "$PSScriptRoot/../Updates.ps1"){. "$PSScriptRoot/../Updates.ps1"}
function New-TestRelease([string]$Version,[bool]$Prerelease=$true) {
    $tag='v'+$Version;$name='ProfileLauncher-'+$Version+'.zip'
    [pscustomobject]@{tag_name=$tag;draft=$false;prerelease=$Prerelease;html_url="https://github.com/yliubchych/profile-orbit/releases/tag/$tag";assets=@([pscustomobject]@{name=$name;state='uploaded';size=1024;digest=('sha256:'+('a'*64));browser_download_url="https://github.com/yliubchych/profile-orbit/releases/download/$tag/$name"})}
}
Test-Case 'Semantic versions order beta numbers, stable releases and reject malformed versions' {
    Assert-Equal 1 (Compare-LauncherVersion '0.1.0-beta.10' '0.1.0-beta.9')
    Assert-Equal 1 (Compare-LauncherVersion '0.1.0' '0.1.0-beta.10')
    Assert-Equal (-1) (Compare-LauncherVersion '0.1.0' '0.2.0')
    Assert-Equal 0 (Compare-LauncherVersion '1.2.3' '1.2.3')
    Assert-Throws {Compare-LauncherVersion '../1.2' '0.1.0'}
    Assert-Throws {Compare-LauncherVersion '1.2.3-beta.01' '0.1.0'}
}
Test-Case 'Beta users see newer betas; stable users ignore prereleases, drafts and downgrades' {
    $beta=New-TestRelease '0.1.0-beta.10';$stable=New-TestRelease '0.1.0' $false
    $draft=New-TestRelease '9.0.0' $false;$draft.draft=$true
    Assert-Equal '0.1.0-beta.10' (Select-LauncherUpdate @($beta,$draft) '0.1.0-beta.3').Version
    Assert-Equal $null (Select-LauncherUpdate @($beta,$draft) '0.1.0')
    Assert-Equal '0.1.0' (Select-LauncherUpdate @($beta,$stable) '0.1.0-beta.3').Version
    Assert-Equal $null (Select-LauncherUpdate @($stable) '1.0.0')
}
Test-Case 'Only exact repository assets with a SHA256 digest are accepted' {
    $release=New-TestRelease '0.2.0' $false
    $release.assets[0].browser_download_url='https://evil.example/update.zip'
    Assert-Equal $null (Select-LauncherUpdate @($release) '0.1.0')
    $release=New-TestRelease '0.2.0' $false;$release.assets[0].digest=$null
    Assert-Equal $null (Select-LauncherUpdate @($release) '0.1.0')
    $release=New-TestRelease '0.2.0' $false;$release.assets+=@($release.assets[0])
    Assert-Equal $null (Select-LauncherUpdate @($release) '0.1.0')
}
Test-Case 'Downloaded ZIP is verified before extraction and file hashes before installation' {
    $root=New-TestRoot;$zip=New-LauncherPackage (Join-Path $PSScriptRoot '..') $root
    $version=([IO.File]::ReadAllText("$PSScriptRoot/../VERSION")).Trim()
    $hash=(Get-FileHash $zip -Algorithm SHA256).Hash
    $source=Expand-LauncherUpdate $zip (Join-Path $root 'stage') $hash $version
    Assert-True (Test-Path (Join-Path $source 'package-manifest.json'))
    Assert-Throws {Expand-LauncherUpdate $zip (Join-Path $root 'bad') ('0'*64) $version} '*checksum*'
    Assert-True (!(Test-Path (Join-Path $root 'bad')))
    Assert-Throws {Expand-LauncherUpdate $zip (Join-Path $root 'wrong-version') $hash '99.0.0'} '*version*'
    [IO.File]::AppendAllText((Join-Path $source 'UI.ps1'),'# changed')
    Assert-Throws {Assert-ReleaseSource $source} '*checksum*'
}
Test-Case 'Archive traversal, unexpected files and duplicate entries are rejected before extraction' {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach($entryNames in @(@('../outside.txt'),@('profiles/auth.json'),@('VERSION','VERSION'))) {
        $root=New-TestRoot;$path=Join-Path $root 'unsafe.zip'
        $zip=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
        try {foreach($name in $entryNames){$entry=$zip.CreateEntry($name);$writer=New-Object IO.StreamWriter($entry.Open());try{$writer.Write('synthetic')}finally{$writer.Dispose()}}}finally{$zip.Dispose()}
        $hash=(Get-FileHash $path -Algorithm SHA256).Hash
        Assert-Throws {Expand-LauncherUpdate $path (Join-Path $root 'stage') $hash '0.1.0'}
        Assert-True (!(Test-Path (Join-Path $root 'stage')))
        Assert-True (!(Test-Path (Join-Path $root 'outside.txt')))
    }
}
Test-Case 'Download staging verifies a mocked GitHub asset and handles connection failure' {
    $root=New-TestRoot;$archive=New-LauncherPackage (Join-Path $PSScriptRoot '..') $root
    $version=([IO.File]::ReadAllText("$PSScriptRoot/../VERSION")).Trim()
    $release=New-TestRelease $version
    $release.assets[0].digest='sha256:'+(Get-FileHash $archive).Hash
    $release.assets[0].size=(Get-Item $archive).Length
    $update=Select-LauncherUpdate @($release) '0.0.0-0'
    $script:MockArchive=$archive
    function Invoke-WebRequest {param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$Headers) Copy-Item -LiteralPath $script:MockArchive -Destination $OutFile}
    $prepared=Save-LauncherUpdate $update (Join-Path $root 'cache')
    Assert-Equal $version $prepared.Version
    Assert-True (Test-Path (Join-Path $prepared.Source 'Launcher.ps1'))
    function Invoke-WebRequest {param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$Headers) throw 'Synthetic offline'}
    Assert-Throws {Save-LauncherUpdate $update (Join-Path $root 'cache')} '*Nothing was installed*'
}
Test-Case 'Update installation preserves profile data and refuses edited installations' {
    $root=New-TestRoot;$source=Join-Path $PSScriptRoot '..';$dest=Join-Path $root 'installed'
    Install-Launcher $source $dest
    $null=New-Item -ItemType Directory (Join-Path $dest 'profiles')
    [IO.File]::WriteAllText((Join-Path $dest 'profiles/sentinel'),'synthetic-account')
    Assert-LauncherUpdateTarget $dest
    Install-Launcher $source $dest
    Assert-Equal 'synthetic-account' ([IO.File]::ReadAllText((Join-Path $dest 'profiles/sentinel')))
    [IO.File]::AppendAllText((Join-Path $dest 'UI.ps1'),'# local edit')
    Assert-Throws {Assert-LauncherUpdateTarget $dest} '*edited*'
    Assert-Throws {Assert-LauncherUpdateTarget $source} '*installed*'
}
Complete-Tests
