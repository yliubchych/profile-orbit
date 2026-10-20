# Local profile metadata only. This file never reads credentials or chat content.
function Get-CanonicalRoot([string]$Root) {
    if ([string]::IsNullOrWhiteSpace($Root)) { throw 'A profile data folder is required.' }
    $full=[IO.Path]::GetFullPath($Root)
    if($full -eq [IO.Path]::GetPathRoot($full)){return $full}
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Get-LauncherLockName([string]$Path, [string]$Kind = 'store') {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant()))).Replace('-','') }
    finally { $sha.Dispose() }
    return "Local\ProfileLauncher-$Kind-$hash"
}
function Invoke-LauncherLock([string]$LockName, [scriptblock]$Operation, [int]$Timeout = 45000) {
    $mutex = New-Object Threading.Mutex($false,$LockName)
    $owned = $false
    try {
        try { $owned = $mutex.WaitOne($Timeout) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (!$owned) { throw 'Another launcher operation is still running. Please retry.' }
        & $Operation
    } finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}
function Assert-ProfileIdentity([string]$Id) {
    if ($Id -cnotmatch '^(PBX|Personal|[a-f0-9]{32})$') { throw 'Invalid profile identifier.' }
}
function Assert-ProfileFields([string]$Name, [string]$Color) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Trim().Length -gt 60 -or $Name -match '[\x00-\x1f]') { throw 'Use a profile name of 1 to 60 characters without control characters.' }
    if ($Color -notmatch '^#[a-fA-F0-9]{6}$') { throw 'Choose a valid profile color.' }
}
function Read-LauncherStore([string]$Root) {
    $Root = Get-CanonicalRoot $Root
    $path = Join-Path $Root 'launcher.json'
    if (!(Test-Path -LiteralPath $path)) {
        $profiles = @()
        foreach ($legacy in @(@('PBX','#9BE4CC'),@('Personal','#AFCBFF'))) {
            if (Test-Path -LiteralPath (Join-Path $Root $legacy[0]) -PathType Container) {
                $profiles += [pscustomobject]@{ Id=$legacy[0]; Name=$legacy[0]; Color=$legacy[1] }
            }
        }
        return [pscustomobject]@{ schemaVersion=1; profiles=@($profiles) }
    }
    try { $store = [IO.File]::ReadAllText($path) | ConvertFrom-Json }
    catch { throw 'Profile metadata could not be read. Preserve launcher.json and restore a known-good copy.' }
    if ($store.schemaVersion -ne 1) { throw 'Unsupported profile metadata schema. Use a compatible launcher version.' }
    if ($null -eq $store.profiles) { throw 'Profile metadata is missing its profile list.' }
    $ids = @{}; $names = @{}
    foreach ($p in @($store.profiles)) {
        Assert-ProfileIdentity $p.Id
        Assert-ProfileFields $p.Name $p.Color
        if ($ids.ContainsKey($p.Id) -or $names.ContainsKey($p.Name.Trim())) { throw 'Profile metadata has duplicate identifiers or names.' }
        $ids[$p.Id]=$true; $names[$p.Name.Trim()]=$true
    }
    return $store
}
function Write-LauncherStore([string]$Root, $Store) {
    $Root = Get-CanonicalRoot $Root
    $null = New-Item -ItemType Directory -Path $Root -Force
    $path = Join-Path $Root 'launcher.json'
    $temp = Join-Path $Root ([guid]::NewGuid().ToString('N')+'.tmp')
    $backup = $temp + '.old'
    try {
        [IO.File]::WriteAllText($temp,($Store | ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp,$path,$backup) } else { [IO.File]::Move($temp,$path) }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
        if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
    }
}
function Get-LauncherProfiles([string]$Root) { (Read-LauncherStore $Root).profiles | ForEach-Object { $_ } }
function Get-LauncherProfile([string]$Root, [string]$Id) {
    Assert-ProfileIdentity $Id
    $found = @((Read-LauncherStore $Root).profiles | Where-Object { $_.Id -ceq $Id })
    if ($found.Count -ne 1) { throw 'Profile not found. Refresh the launcher and try again.' }
    return $found[0]
}
function Add-LauncherProfile([string]$Root, [string]$Name, [string]$Color) {
    Assert-ProfileFields $Name $Color
    Invoke-LauncherLock (Get-LauncherLockName (Get-CanonicalRoot $Root)) {
        $store = Read-LauncherStore $Root
        if (@($store.profiles | Where-Object { $_.Name.Trim() -ieq $Name.Trim() }).Count) { throw 'A profile with this name already exists.' }
        $p = [pscustomobject]@{ Id=[guid]::NewGuid().ToString('N'); Name=$Name.Trim(); Color=$Color.ToUpperInvariant() }
        $store.profiles = @($store.profiles) + @($p)
        Write-LauncherStore $Root $store
        return $p
    }
}
function Update-LauncherProfile([string]$Root, [string]$Id, [string]$Name, [string]$Color) {
    Assert-ProfileFields $Name $Color
    Invoke-LauncherLock (Get-LauncherLockName (Get-CanonicalRoot $Root)) {
        $store = Read-LauncherStore $Root
        $p = @($store.profiles | Where-Object { $_.Id -ceq $Id })
        if ($p.Count -ne 1) { throw 'Profile not found.' }
        if (@($store.profiles | Where-Object { $_.Id -cne $Id -and $_.Name.Trim() -ieq $Name.Trim() }).Count) { throw 'A profile with this name already exists.' }
        $p[0].Name=$Name.Trim(); $p[0].Color=$Color.ToUpperInvariant()
        Write-LauncherStore $Root $store
        return $p[0]
    }
}
function Assert-ProjectFolder([string]$Path) {
    if ($Path -notmatch '^[a-zA-Z]:[\\/]' -or !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Choose an existing local project folder with an absolute path.'
    }
    return [IO.Path]::GetFullPath($Path)
}
function Get-LauncherProjects([string]$Root, [string]$Id) {
    $p=Get-LauncherProfile $Root $Id
    if ($null -ne $p.Projects) { $p.Projects | ForEach-Object {$_} }
}
function Add-LauncherProject([string]$Root, [string]$Id, [string]$Name, [string]$Path) {
    Assert-ProfileFields $Name '#9BE4CC'
    $resolved=Assert-ProjectFolder $Path
    Invoke-LauncherLock (Get-LauncherLockName (Get-CanonicalRoot $Root)) {
        $store=Read-LauncherStore $Root
        $p=@($store.profiles | Where-Object {$_.Id -ceq $Id})
        if($p.Count -ne 1){throw 'Profile not found.'}
        $items=@();if($null -ne $p[0].Projects){$items=@($p[0].Projects)}
        if(@($items | Where-Object {$_.Name -ieq $Name.Trim() -or $_.Path.TrimEnd('\') -ieq $resolved.TrimEnd('\')}).Count){throw 'This project name or folder already exists in this profile.'}
        $item=[pscustomobject]@{Id=[guid]::NewGuid().ToString('N');Name=$Name.Trim();Path=$resolved}
        $p[0] | Add-Member NoteProperty Projects (@($items)+@($item)) -Force
        Write-LauncherStore $Root $store
        return $item
    }
}
function Remove-LauncherProject([string]$Root, [string]$Id, [string]$ProjectId) {
    Invoke-LauncherLock (Get-LauncherLockName (Get-CanonicalRoot $Root)) {
        $store=Read-LauncherStore $Root
        $p=@($store.profiles | Where-Object {$_.Id -ceq $Id})
        if($p.Count -ne 1 -or @($p[0].Projects | Where-Object {$_.Id -ceq $ProjectId}).Count -ne 1){throw 'Project shortcut not found.'}
        $p[0].Projects=@($p[0].Projects | Where-Object {$_.Id -cne $ProjectId})
        Write-LauncherStore $Root $store
    }
}
function New-ProjectDeepLink([string]$Path) {
    $resolved=Assert-ProjectFolder $Path
    return 'codex://threads/new?path='+[Uri]::EscapeDataString($resolved)
}
function Get-LauncherCompatibility([string]$Version) {
    if($Version -in @('26.1007.2314.0','26.1013.4894.0')){return 'LocallyChecked'}
    return 'Unverified'
}
function Get-LauncherUserMessage([string]$Code) {
    switch($Code) {
        'app-missing' {return 'Install the official Codex desktop app for this Windows user, then retry.'}
        'metadata-invalid' {return 'Profile settings could not be read. Keep launcher.json and restore a known-good copy; account data has not been reset.'}
        'low-memory' {return 'Close unused applications and retry. A stopped profile requires 2.5 GB free RAM.'}
        'app-unverified' {return 'This app build has not been checked locally. Verify focus, reopen and project navigation before relying on it.'}
        default {return 'The action could not be completed. Check Diagnostics, then retry. No account data was reset.'}
    }
}
function Read-LauncherEvents([string]$Root) {
    $path=Join-Path $Root 'events.json'
    if(!(Test-Path -LiteralPath $path)){return}
    try {
        $items=[IO.File]::ReadAllText($path)|ConvertFrom-Json
        foreach($event in @($items | Select-Object -Last 50)) {
            $time=''
            if($event.Time -is [DateTime]){$time=$event.Time.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')}
            elseif($event.Time -is [string] -and $event.Time -match '^\d{4}-\d\d-\d\dT[0-9:.]+Z$'){$time=$event.Time}
            if($event.Action -in @('launch','close','project','setup') -and $event.Code -in @('ok','unavailable','failed','timeout') -and $time) {
                [pscustomobject]@{Time=$time;Action=[string]$event.Action;Code=[string]$event.Code}
            }
        }
    } catch { return }
}
function Write-LauncherEvent([string]$Root,[ValidateSet('launch','close','project','setup')][string]$Action,[ValidateSet('ok','unavailable','failed','timeout')][string]$Code) {
    Invoke-LauncherLock (Get-LauncherLockName (Get-CanonicalRoot $Root) 'events') {
        $null=New-Item -ItemType Directory -Path $Root -Force
        $events=@(Read-LauncherEvents $Root)+@([pscustomobject]@{Time=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ');Action=$Action;Code=$Code})
        [IO.File]::WriteAllText((Join-Path $Root 'events.json'),(ConvertTo-Json -InputObject @($events | Select-Object -Last 50) -Depth 5),[Text.UTF8Encoding]::new($false))
    }
}
function Get-LauncherDiagnostic([string]$Root) {
    $checks=@();$version='Unavailable';$compatibility='Unavailable';$count=0;$states=@();$memory=$null
    try {
        $info=Get-InstalledCodexInfo
        if($info.Version -notmatch '^\d+(\.\d+){1,3}$'){throw 'Invalid app version'}
        $version=[string]$info.Version;$compatibility=Get-LauncherCompatibility $version
        if($compatibility -eq 'Unverified'){$checks+=@('app-unverified')}
    } catch {$checks+=@('app-missing')}
    try {
        $profiles=@(Get-LauncherProfiles $Root);$count=$profiles.Count
        foreach($p in $profiles){
            $state=Get-LauncherProfileState $Root $p.Id
            $value='Unknown';if($state.Status -in @('Open','Background','Stopped','Unknown')){$value=$state.Status}
            $states+=@($value)
        }
    } catch {$checks+=@('metadata-invalid')}
    try {$memory=[int](Get-FreeMemoryMB);if($memory -lt 2560){$checks+=@('low-memory')}}catch{$checks+=@('memory-unavailable')}
    $launcherVersion=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
    return [pscustomobject][ordered]@{SchemaVersion=1;Time=[DateTime]::UtcNow.ToString('o');LauncherVersion=$launcherVersion;AppVersion=$version;Compatibility=$compatibility;WindowsVersion=[Environment]::OSVersion.Version.ToString();FreeMemoryMB=$memory;ProfileCount=$count;ProfileStates=@($states);Checks=@($checks);Events=@(Read-LauncherEvents $Root)}
}
function Export-LauncherDiagnostic($Report,[string]$Path) {
    # Report is produced from a whitelist; never export raw exceptions or environment variables.
    [IO.File]::WriteAllText($Path,($Report|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
}
function Get-LauncherHotkeyDefinitions([string]$Root) {
    [pscustomobject]@{Id=1;Key=76;Target='launcher';Label='Ctrl+Alt+Shift+L'}
    $profiles=@(Get-LauncherProfiles $Root | Select-Object -First 9)
    for($index=0;$index -lt $profiles.Count;$index++) {
        [pscustomobject]@{Id=10+$index;Key=49+$index;Target=$profiles[$index].Id;Label=('Ctrl+Alt+Shift+'+($index+1))}
    }
}
function New-LauncherSession([string]$Root) {
    $name=Get-LauncherLockName (Get-CanonicalRoot $Root) 'window'
    $mutex=New-Object Threading.Mutex($false,$name)
    $event=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::AutoReset,($name+'-focus'))
    $owned=$false
    try{try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}}
    catch{$event.Dispose();$mutex.Dispose();throw}
    if(!$owned){$null=$event.Set()}
    return [pscustomobject]@{Mutex=$mutex;FocusEvent=$event;Owned=$owned;Closed=$false}
}
function Close-LauncherSession($Session) {
    if($null -eq $Session -or $Session.Closed){return}
    if($Session.Owned){$Session.Mutex.ReleaseMutex()}
    $Session.FocusEvent.Dispose();$Session.Mutex.Dispose();$Session.Closed=$true
}
