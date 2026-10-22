function Get-ProfileProcess([string]$DataPath) {
    $escaped = [regex]::Escape($DataPath)
    $argument = '(?i)(?:^|\s)--user-data-dir=(?:"' + $escaped + '"|' + $escaped + '(?=\s|$))'
    Get-CimInstance Win32_Process -Filter "Name = 'ChatGPT.exe' OR Name = 'Codex.exe'" |
        Where-Object { $_.CommandLine -match $argument -and $_.CommandLine -notmatch '--type=' }
}

function New-LauncherUIStartInfo([string]$Script,[string]$DataRoot) {
    $quoted=@(foreach($value in @($Script,$DataRoot)) {
        if($value.Contains('"') -or $value -match '[\r\n]'){throw 'Invalid launcher process argument.'}
        '"'+[regex]::Replace($value,'(\\+)$','$1$1')+'"'
    })
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -ExecutionPolicy Bypass -STA -File '+$quoted[0]+' -Detached -DataRoot '+$quoted[1]
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$true
    $info.WindowStyle='Hidden'
    return $info
}

function Stop-CodexProfile([string]$Name) {
    $null=Get-LauncherProfile $profileRoot $Name
    Invoke-LauncherLock (Get-LauncherLockName (Join-Path $profileRoot $Name) 'profile') { Stop-CodexProfileCore $Name }
}
function Stop-CodexProfileCore([string]$Name) {
    $null = Get-LauncherProfile $profileRoot $Name
    $data = Join-Path (Join-Path $profileRoot $Name) 'desktop'
    $targets = @(Get-ProfileProcess $data)
    if ($targets.Count -eq 0) { return "$Name is already closed." }
    if ($targets.Count -ne 1) { throw 'More than one main process matches this profile. Nothing was stopped.' }
    $target = $targets[0]
    # Recheck identity immediately before stopping; never terminate by executable name.
    $current = @(Get-ProfileProcess $data)
    if ($current.Count -ne 1 -or $current[0].ProcessId -ne $target.ProcessId -or
        $current[0].CreationDate -ne $target.CreationDate) {
        throw 'The profile process changed. Please retry.'
    }
    Invoke-ProfileStopProcess ([int]$target.ProcessId)
    if (@(Get-ProfileProcess $data).Count -gt 0) { throw "$Name is still running. Please retry." }
    return "$Name fully closed (including background processes)."
}

function Invoke-ProfileStopProcess([int]$ProcessId) {
    $stopInfo = New-Object Diagnostics.ProcessStartInfo
    $stopInfo.FileName = Join-Path $env:SystemRoot 'System32\taskkill.exe'
    $stopInfo.Arguments = '/PID ' + [int]$ProcessId + ' /T /F'
    $stopInfo.UseShellExecute = $false
    $stopInfo.CreateNoWindow = $true
    $stopInfo.RedirectStandardOutput = $true
    $stopInfo.RedirectStandardError = $true
    $stopProcess = [Diagnostics.Process]::Start($stopInfo)
    $null = $stopProcess.StandardOutput.ReadToEnd()
    $errorText = $stopProcess.StandardError.ReadToEnd()
    $stopProcess.WaitForExit()
    if ($stopProcess.ExitCode -ne 0) { throw "Could not fully close $Name. $errorText" }
}

function Initialize-ProfileWindows {
    if ('CodexProfileWindows' -as [type]) { return }
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class CodexProfileWindows {
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextLength(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr h, int cmd);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 public static IntPtr[] Find(int processId) {
  var visible = new List<IntPtr>();
  EnumWindows((h,p) => { uint id; GetWindowThreadProcessId(h,out id);
   if (id != (uint)processId) return true;
   var cls = new StringBuilder(256); GetClassName(h,cls,cls.Capacity);
   if (cls.ToString() != "Chrome_WidgetWin_1" || GetWindowTextLength(h) == 0) return true;
   if (IsWindowVisible(h)) visible.Add(h);
   return true;
  },IntPtr.Zero);
  return visible.ToArray();
 }
 public static bool Activate(IntPtr h,int expectedProcessId) {
  uint id; GetWindowThreadProcessId(h,out id); if(id!=(uint)expectedProcessId)return false;
  ShowWindowAsync(h,IsIconic(h) ? 9 : 5);
  return SetForegroundWindow(h);
 }
}
"@

}

function Get-ProfileWindow([int]$ProcessId) {
    Initialize-ProfileWindows
    # Enumerate visible profile windows, including minimized windows.
    # Hidden Electron windows must be reopened through the app lifecycle.
    $windows = @([CodexProfileWindows]::Find($ProcessId))
    if ($windows.Count -eq 0) { return [IntPtr]::Zero }
    return $windows[0]
}

function Get-ProfileWindows([int]$ProcessId) {
    Initialize-ProfileWindows
    [CodexProfileWindows]::Find($ProcessId) | ForEach-Object { $_ }
}
function Get-LauncherProfileState([string]$Root, [string]$Id) {
    $null=Get-LauncherProfile $Root $Id
    try {
        $processes=@(Get-ProfileProcess (Join-Path (Join-Path $Root $Id) 'desktop'))
        if ($processes.Count -gt 1) { throw 'Ambiguous profile process identity.' }
        if ($processes.Count -eq 0) { return [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0;ProcessId=$null} }
        $windows=@(Get-ProfileWindows $processes[0].ProcessId)
        if ($windows.Count -gt 0) { return [pscustomobject]@{Status='Open';Action='Focus';WindowCount=$windows.Count;ProcessId=$processes[0].ProcessId} }
        return [pscustomobject]@{Status='Background';Action='Reopen';WindowCount=0;ProcessId=$processes[0].ProcessId}
    } catch { return [pscustomobject]@{Status='Unknown';Action='Unavailable';WindowCount=0;ProcessId=$null} }
}
function Get-FreeMemoryMB { return (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreePhysicalMemory / 1024 }
function Set-ProfileWindowForeground([IntPtr]$Window,[int]$ProcessId) {
    Initialize-ProfileWindows
    return [CodexProfileWindows]::Activate($Window,$ProcessId)
}

function Open-ExistingProfile($Existing, [string]$Name) {
    if ((Get-ProfileWindow $Existing.ProcessId) -eq [IntPtr]::Zero) {
        $root = Join-Path $profileRoot $Name
        $data = Join-Path $root 'desktop'
        # Re-launching the same profile forwards activation to its existing process.
        # Never stop the profile or its running tasks to restore a window.
        Invoke-ProfileLaunch (Find-CodexApp) $data (Join-Path $root 'codex')
        $null = Wait-ProfileWindow $data $Name
    }
    $identityPath=Join-Path (Join-Path $profileRoot $Name) 'desktop'
    $current=@(Get-ProfileProcess $identityPath)
    if($current.Count -ne 1 -or $current[0].ProcessId -ne $Existing.ProcessId -or $current[0].CreationDate -ne $Existing.CreationDate){throw 'The profile process changed while opening its window. No process was stopped; please retry.'}
    $window = Get-ProfileWindow $Existing.ProcessId
    if ($window -eq [IntPtr]::Zero) {
        throw "$Name has no accessible window yet. No process was stopped; please retry."
    }
    # Restore this exact visible/minimized window. Do not
    # request another app launch if Windows refuses foreground activation.
    if (!(Set-ProfileWindowForeground $window $Existing.ProcessId)) {
        $activate = New-Object -ComObject WScript.Shell
        if (!$activate.AppActivate([int]$Existing.ProcessId)) {
            throw "The $Name window was restored, but Windows did not allow focus. Select it from the taskbar."
        }
    }
    return [int]$Existing.ProcessId
}

function Wait-ProfileWindow([string]$DataPath, [string]$Name) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $matches = @(Get-ProfileProcess $DataPath)
        if ($matches.Count -gt 1) { throw "Multiple main processes match $Name." }
        if ($matches.Count -eq 1 -and (Get-ProfileWindow $matches[0].ProcessId) -ne [IntPtr]::Zero) {
            return [int]$matches[0].ProcessId
        }
        Start-Sleep -Milliseconds 500
    }
    throw "$Name did not show an accessible window within 30 seconds. It may still be starting or running in the background; no process was stopped."
}

function Find-CodexApp {
    return (Get-InstalledCodexInfo).Path
}
. "$PSScriptRoot/CallbackRouting.ps1"
function Get-InstalledCodexInfo {
    $packages = @(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue | Sort-Object Version -Descending)
    foreach ($package in $packages) {
        foreach ($name in @('ChatGPT.exe','Codex.exe')) {
            $candidate = Join-Path $package.InstallLocation "app\$name"
            if (Test-Path -LiteralPath $candidate) { return [pscustomobject]@{Path=$candidate;Version=$package.Version.ToString()} }
        }
    }
    throw 'Codex desktop installation was not found. Install or update Codex for this Windows user.'
}

function New-ProfileStartInfo([string]$App, [string]$Data, [string]$Codex, [string]$DeepLink='') {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $app
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = Split-Path -Parent $app
    $start.Arguments = '--user-data-dir="' + $data + '"'
    if($DeepLink) {
        if($DeepLink -cnotmatch '^codex://threads/new\?path=[A-Za-z0-9%._~-]+$' -and $DeepLink -cne (New-LauncherPluginsLink)){$null=Assert-ConnectorCallbackLink $DeepLink}
        $start.Arguments += ' "'+$DeepLink+'"'
    }
    # Do not pass the launching agent's connection/authentication context to a new profile.
    foreach ($key in @($start.EnvironmentVariables.Keys)) {
        if ($key -match '^(CODEX_|OPENAI_)' -or $key -eq 'ELECTRON_RUN_AS_NODE') {
            $start.EnvironmentVariables.Remove($key)
        }
    }
    $start.EnvironmentVariables['CODEX_HOME'] = $codex
    $start.EnvironmentVariables['CODEX_ELECTRON_USER_DATA_PATH'] = $data
    return $start
}
function Invoke-ProfileLaunch([string]$App, [string]$Data, [string]$Codex, [string]$DeepLink='') {
    $start=New-ProfileStartInfo $App $Data $Codex $DeepLink
    $process=[Diagnostics.Process]::Start($start)
    if($null -ne $process){$process.Dispose()}
}

function Invoke-LauncherProject([string]$Root, [string]$Id, [string]$ProjectId) {
    $project=@(Get-LauncherProjects $Root $Id | Where-Object {$_.Id -ceq $ProjectId})
    if($project.Count -ne 1){throw 'Project shortcut not found in this profile.'}
    $link=New-ProjectDeepLink $project[0].Path
    $profileRoot=Get-CanonicalRoot $Root
    Invoke-LauncherLock (Get-LauncherLockName (Join-Path $profileRoot $Id) 'profile') {
        $null=Start-CodexProfile $Id
        $base=Join-Path $profileRoot $Id
        # Send directly to this app/data-root pair; never use Windows' shared URL handler.
        Invoke-ProfileLaunch (Find-CodexApp) (Join-Path $base 'desktop') (Join-Path $base 'codex') $link
    }
}

function Invoke-LauncherPlugins([string]$Root,[string]$Id) {
    $null=Get-LauncherProfile $Root $Id
    $profileRoot=Get-CanonicalRoot $Root
    $base=Join-Path $profileRoot $Id
    Invoke-LauncherLock (Get-LauncherLockName $base 'profile') {
        $null=Start-CodexProfile $Id
        # Direct delivery keeps the browser and its cookies in the selected app instance.
        Invoke-ProfileLaunch (Find-CodexApp) (Join-Path $base 'desktop') (Join-Path $base 'codex') (New-LauncherPluginsLink)
    }
}
function Start-CodexProfile([string]$Name) {
    $null=Get-LauncherProfile $profileRoot $Name
    $lockPath=Join-Path $profileRoot $Name
    Invoke-LauncherLock (Get-LauncherLockName $lockPath 'profile') { Start-CodexProfileCore $Name }
}
function Start-CodexProfileCore([string]$Name) {
    $null = Get-LauncherProfile $profileRoot $Name
    $root = Join-Path $profileRoot $Name
    $data = Join-Path $root 'desktop'
    $codex = Join-Path $root 'codex'
    $existing = @(Get-ProfileProcess $data)
    if ($existing.Count -gt 1) { throw 'Multiple main processes match this profile.' }
    if ($existing.Count -eq 1) { return (Open-ExistingProfile $existing[0] $Name) }
    $freeMB = Get-FreeMemoryMB
    if ($freeMB -lt 2560) {
        throw ('Not enough free RAM to start another Codex safely ({0:N0} MB available). Close unused apps or another Codex window, then retry. At least 2.5 GB free is required by this launcher.' -f $freeMB)
    }
    $app = Find-CodexApp
    New-Item -ItemType Directory -Path $data,$codex -Force | Out-Null
    $config = Join-Path $codex 'config.toml'
    if (!(Test-Path -LiteralPath $config)) {
        [IO.File]::WriteAllText($config, "cli_auth_credentials_store = `"file`"`n", [Text.UTF8Encoding]::new($false))
    }
    Invoke-ProfileLaunch $app $data $codex
    return (Wait-ProfileWindow $data $Name)
}

function Initialize-LauncherHotkeys {
    if('LauncherHotkeyWindow' -as [type]){return}
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public sealed class LauncherHotkeyEventArgs : EventArgs { public int Id {get; private set;} public LauncherHotkeyEventArgs(int id){Id=id;} }
public sealed class LauncherHotkeyWindow : NativeWindow, IDisposable {
 [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h,int id,uint mods,uint key);
 [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h,int id);
 readonly List<int> registrations=new List<int>();
 public object Context {get;set;}
 public event EventHandler<LauncherHotkeyEventArgs> Pressed;
 public LauncherHotkeyWindow(){CreateHandle(new CreateParams {Caption="ProfileLauncherHotkeys",Parent=new IntPtr(-3)});}
 public bool Register(int id,uint key){bool ok=RegisterHotKey(Handle,id,0x4007,key);if(ok)registrations.Add(id);return ok;}
 protected override void WndProc(ref Message m){if(m.Msg==0x0312){var handler=Pressed;if(handler!=null)handler(this,new LauncherHotkeyEventArgs(m.WParam.ToInt32()));}base.WndProc(ref m);}
 public void Dispose(){foreach(int id in registrations)UnregisterHotKey(Handle,id);registrations.Clear();if(Handle!=IntPtr.Zero)DestroyHandle();}
}
"@
}

