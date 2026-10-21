# Source-only packaging and per-user installation. Never traverse runtime profiles.
. "$PSScriptRoot/CallbackRouting.ps1"
function Get-LauncherReleaseFiles {
    @('Launcher.ps1','Core.ps1','Windows.ps1','UI.ps1','CallbackRouting.ps1','Release.ps1','Start.cmd','Install.ps1','Install.cmd','Uninstall.ps1','README.md','VERSION')
}
function Assert-ReleaseSource([string]$Source) {
    foreach($file in Get-LauncherReleaseFiles) {
        $path=Join-Path $Source $file
        if(!(Test-Path -LiteralPath $path -PathType Leaf) -or ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Incomplete or unsafe release source. Extract the complete package and retry.'}
        if($file -like '*.ps1') {
            $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
            if($errors.Count){throw 'Invalid script in release source.'}
        }
    }
    $manifestPath=Join-Path $Source 'package-manifest.json'
    if(Test-Path -LiteralPath $manifestPath) {
        $manifest=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
        if($manifest.Product -ne 'ProfileLauncher'){throw 'Invalid release source manifest.'}
        foreach($file in Get-LauncherReleaseFiles) {
            if($manifest.Hashes.$file -cne (Get-FileHash (Join-Path $Source $file) -Algorithm SHA256).Hash){throw 'Release source checksum mismatch. Download a fresh package.'}
        }
    }
}
function Assert-InstallDirectory([string]$Destination) {
    $full=Get-CanonicalRoot $Destination
    if($full.TrimEnd('\') -ieq ([IO.Path]::GetPathRoot($full)).TrimEnd('\')){throw 'Choose a dedicated installation folder, not a drive root.'}
    $walk=$full
    while($walk) {
        if(Test-Path -LiteralPath $walk) {
            if((Get-Item -LiteralPath $walk -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Installation through a linked folder is not supported.'}
        }
        $parent=Split-Path $walk -Parent
        if($parent -eq $walk){break};$walk=$parent
    }
    return $full
}
function New-LauncherPackage([string]$Source,[string]$Output) {
    Assert-ReleaseSource $Source
    $version=([IO.File]::ReadAllText((Join-Path $Source 'VERSION'))).Trim()
    if($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9.]+)?$'){throw 'Invalid release version.'}
    $null=New-Item -ItemType Directory -Path $Output -Force
    $target=Join-Path $Output ("ProfileLauncher-$version.zip")
    if(Test-Path -LiteralPath $target){throw 'A release archive with this name already exists.'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $zip=[IO.Compression.ZipFile]::Open($target,[IO.Compression.ZipArchiveMode]::Create)
    try {
        $hashes=[ordered]@{}
        foreach($file in Get-LauncherReleaseFiles) {
            $path=Join-Path $Source $file
            $hashes[$file]=(Get-FileHash $path -Algorithm SHA256).Hash
            $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$path,$file)
        }
        $entry=$zip.CreateEntry('package-manifest.json');$writer=New-Object IO.StreamWriter($entry.Open(),[Text.UTF8Encoding]::new($false))
        try {$writer.Write(([ordered]@{Product='ProfileLauncher';Version=$version;Hashes=$hashes}|ConvertTo-Json -Depth 10))}finally{$writer.Dispose()}
    } finally {$zip.Dispose()}
    return [IO.Path]::GetFullPath($target)
}
function Read-InstallManifest([string]$Destination) {
    $path=Join-Path $Destination 'installation.json'
    if((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Invalid linked installation manifest.'}
    try{$manifest=[IO.File]::ReadAllText($path)|ConvertFrom-Json}catch{throw 'Installation manifest is missing or invalid. Nothing was removed.'}
    if($manifest.Product -ne 'ProfileLauncher' -or $null -eq $manifest.Files -or $null -eq $manifest.Hashes){throw 'Invalid installation manifest.'}
    $allowed=@(Get-LauncherReleaseFiles)
    foreach($file in $manifest.Files){if($allowed -cnotcontains $file){throw 'Invalid installation manifest file list.'}}
    if(@($manifest.Files | Select-Object -Unique).Count -ne @($manifest.Files).Count){throw 'Invalid installation manifest duplicates.'}
    return $manifest
}
function Install-Launcher([string]$Source,[string]$Destination) {
    Assert-ReleaseSource $Source
    $dest=Assert-InstallDirectory $Destination
    if((Get-CanonicalRoot $Source) -ieq $dest){throw 'Choose an installation folder separate from the release source.'}
    $files=@(Get-LauncherReleaseFiles)
    $prior=$null
    if(Test-Path -LiteralPath (Join-Path $dest 'installation.json')){$prior=Read-InstallManifest $dest}
    foreach($file in $files) {
        $path=Join-Path $dest $file
        if(Test-Path -LiteralPath $path){
            if((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'An installation file is a link. Nothing was changed.'}
            if($null -eq $prior -or $prior.Files -cnotcontains $file){throw 'An unmanaged file already exists at the installation destination.'}
            if((Get-FileHash $path -Algorithm SHA256).Hash -cne $prior.Hashes.$file){throw 'An installed file was edited. Preserve your changes before updating.'}
        }
    }
    $null=New-Item -ItemType Directory -Path $dest -Force
    $saved=@{};$written=@()
    try {
        foreach($file in @($files)+@('installation.json')) {
            $path=Join-Path $dest $file
            if([IO.File]::Exists($path)){$saved[$file]=[IO.File]::ReadAllBytes($path)}
            $written+=@($file)
            if($file -ne 'installation.json'){[IO.File]::WriteAllBytes($path,[IO.File]::ReadAllBytes((Join-Path $Source $file)))}
        }
        $hashes=[ordered]@{};foreach($file in $files){$hashes[$file]=(Get-FileHash (Join-Path $dest $file) -Algorithm SHA256).Hash}
        $manifest=[ordered]@{Product='ProfileLauncher';Version=([IO.File]::ReadAllText((Join-Path $dest 'VERSION'))).Trim();Files=$files;Hashes=$hashes}
        [IO.File]::WriteAllText((Join-Path $dest 'installation.json'),($manifest|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
    } catch {
        foreach($file in $written){$path=Join-Path $dest $file;if($saved.ContainsKey($file)){[IO.File]::WriteAllBytes($path,$saved[$file])}elseif([IO.File]::Exists($path)){[IO.File]::Delete($path)}}
        throw 'Installation failed and managed files were rolled back. Close the launcher and retry.'
    }
}
function Uninstall-Launcher([string]$Destination) {
    $dest=Assert-InstallDirectory $Destination
    $manifest=Read-InstallManifest $dest
    # Validate every resolved target before deleting any file. Never recurse.
    foreach($file in $manifest.Files){$path=Join-Path $dest $file;if(Test-Path -LiteralPath $path){if((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsafe linked installation file. Nothing was removed.'}}}
    $preserved=@()
    foreach($file in $manifest.Files){$path=Join-Path $dest $file;if([IO.File]::Exists($path)){if((Get-FileHash $path -Algorithm SHA256).Hash -ceq $manifest.Hashes.$file){[IO.File]::Delete($path)}else{$preserved+=@($file)}}}
    if($preserved.Count -eq 0){[IO.File]::Delete((Join-Path $dest 'installation.json'))}
    # Profile folders, metadata, diagnostics, project folders and unknown files stay in place.
}
function Get-LauncherShortcutArguments([string]$Destination) {
    return '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "'+(Join-Path (Get-CanonicalRoot $Destination) 'Launcher.ps1')+'"'
}
function New-LauncherShortcut([string]$Destination,[string]$Shortcut) {
    $target=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments=Get-LauncherShortcutArguments $Destination
    $shell=New-Object -ComObject WScript.Shell
    $exists=Test-Path -LiteralPath $Shortcut
    $link=$shell.CreateShortcut($Shortcut)
    if($exists){
        if($link.TargetPath -ieq $target -and $link.Arguments -ceq $arguments){return 'Unchanged'}
        return 'PreservedOther'
    }
    $link.TargetPath=$target;$link.Arguments=$arguments;$link.WorkingDirectory=Get-CanonicalRoot $Destination;$link.Save()
    return 'Created'
}
function Remove-LauncherShortcut([string]$Destination,[string]$Shortcut) {
    if(!(Test-Path -LiteralPath $Shortcut)){return}
    $shell=New-Object -ComObject WScript.Shell;$link=$shell.CreateShortcut($Shortcut)
    $target=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if($link.TargetPath -ieq $target -and $link.Arguments -ceq (Get-LauncherShortcutArguments $Destination)){[IO.File]::Delete($Shortcut)}
}
