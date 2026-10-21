# Authorization URLs remain opaque and in memory, never in logs or metadata.
function Assert-LauncherUrl([string]$Link) {
    if($Link.Length -gt 16384 -or $Link -cnotmatch '^codex://[A-Za-z0-9%._~!$&''()*+,;=:@/?#-]+$' -or $Link -match '%(?![a-fA-F0-9]{2})'){throw 'Invalid desktop return link.'}
    return $Link
}
function Assert-ConnectorCallbackLink([string]$Link) {
    $null=Assert-LauncherUrl $Link
    if($Link -cnotmatch '^codex://connector/oauth_callback\?[^#]+$'){throw 'Invalid connector return link.'}
    return $Link
}
function New-CallbackTargetDialog($Targets) {
    Add-Type -AssemblyName System.Windows.Forms
    $form=New-Object Windows.Forms.Form
    $form.Text='Return plugin authorization';$form.ClientSize=New-Object Drawing.Size(500,260)
    $form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
    $label=New-Object Windows.Forms.Label;$label.SetBounds(20,18,460,52)
    $label.Text='Choose the window where you started connecting this plugin. ChatGPT will validate the authorization.'
    $list=New-Object Windows.Forms.ListBox;$list.SetBounds(20,76,460,110);$list.DisplayMember='Name'
    foreach($target in $Targets){[void]$list.Items.Add($target)}
    $list.SelectedIndex=-1
    $ok=New-Object Windows.Forms.Button;$ok.Text='Return to selected';$ok.SetBounds(270,204,210,36);$ok.Enabled=$false
    $cancel=New-Object Windows.Forms.Button;$cancel.Text='Cancel';$cancel.SetBounds(20,204,120,36);$cancel.DialogResult='Cancel'
    $form.Controls.AddRange(@($label,$list,$ok,$cancel));$form.CancelButton=$cancel;$form.AcceptButton=$ok
    $form.Tag=@{List=$list;Continue=$ok}
    $list.Add_SelectedIndexChanged({$this.FindForm().Tag.Continue.Enabled=($this.SelectedIndex -ge 0)})
    $ok.Add_Click({$this.FindForm().DialogResult='OK'})
    return $form
}
function Select-LauncherCallbackTarget($Targets) {
    $form=New-CallbackTargetDialog $Targets
    try {if($form.ShowDialog() -eq 'OK' -and $null -ne $form.Tag.List.SelectedItem){return $form.Tag.List.SelectedItem.Id}}
    finally {$form.Dispose()}
}
function Invoke-LauncherCallback([string]$Root,[string]$Link) {
    $null=Assert-LauncherUrl $Link
    if($Link -cnotmatch '^codex://connector/oauth_callback(?:[/?#]|$)'){Invoke-DefaultCallback $Link;return}
    $null=Assert-ConnectorCallbackLink $Link
    Invoke-LauncherLock (Get-LauncherLockName ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) 'callback') {
        $targets=@([pscustomobject]@{Id='default';Name='Default ChatGPT window';Process=$null})
        foreach($p in @(Get-LauncherProfiles $Root)) {
            $processes=@(Get-ProfileProcess (Join-Path (Join-Path $Root $p.Id) 'desktop'))
            if($processes.Count -eq 1){$targets+=@([pscustomobject]@{Id=$p.Id;Name=$p.Name;Process=$processes[0]})}
        }
        $choice=Select-LauncherCallbackTarget $targets
        if([string]::IsNullOrEmpty($choice)){return}
        if($choice -ceq 'default'){Invoke-DefaultCallback $Link;return}
        $target=@($targets | Where-Object {$_.Id -ceq $choice})
        if($target.Count -ne 1){throw 'Invalid callback profile selection.'}
        $null=Get-LauncherProfile $Root $choice
        $base=Join-Path $Root $choice;$data=Join-Path $base 'desktop'
        Invoke-LauncherLock (Get-LauncherLockName $base 'profile') {
            $current=@(Get-ProfileProcess $data)
            if($current.Count -ne 1 -or $current[0].ProcessId -ne $target[0].Process.ProcessId -or $current[0].CreationDate -ne $target[0].Process.CreationDate){throw 'The profile changed or closed. Retry connecting from that profile.'}
            Invoke-ProfileLaunch (Find-CodexApp) $data (Join-Path $base 'codex') $Link
        }
    } 0
}
function New-DefaultCallbackStartInfo([string]$App,[string]$Link) {
    $null=Assert-LauncherUrl $Link
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$App;$start.Arguments='"'+$Link+'"';$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.WorkingDirectory=Split-Path -Parent $App
    foreach($key in @($start.EnvironmentVariables.Keys)) {
        if($key -match '^(CODEX_|OPENAI_)' -or $key -eq 'ELECTRON_RUN_AS_NODE'){$start.EnvironmentVariables.Remove($key)}
    }
    return $start
}
function Invoke-DefaultCallback([string]$Link) {
    $process=[Diagnostics.Process]::Start((New-DefaultCallbackStartInfo (Find-CodexApp) $Link))
    if($null -ne $process){$process.Dispose()}
}
function Get-CallbackProtocolKey {return 'Software\Classes\codex'}
function Get-CallbackRoutingLockName {return (Get-LauncherLockName ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) 'protocol')}
function Get-CallbackHandlerCommand([string]$Root,[string]$Script) {
    foreach($path in @($Root,$Script)){if($path -match '["\x00-\x1f%]'){throw 'Unsupported callback handler path.'}}
    $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $Root=$Root -replace '(\\+)$','$1$1'
    return '"'+$powershell+'" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "'+$Script+'" "'+$Root+'" "%1"'
}
function Initialize-CallbackShell {
    if('ProfileLauncherShell' -as [type]){return}
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ProfileLauncherShell {
 [DllImport("shlwapi.dll", CharSet=CharSet.Unicode)] static extern uint AssocQueryString(uint flags,uint str,string assoc,string extra,StringBuilder output,ref uint length);
 [DllImport("shell32.dll")] static extern void SHChangeNotify(uint eventId,uint flags,IntPtr item1,IntPtr item2);
 public static void Changed(){SHChangeNotify(0x08000000,0x1000,IntPtr.Zero,IntPtr.Zero);}
 public static string Command(){uint size=32768;var s=new StringBuilder((int)size);return AssocQueryString(0x1000,1,"codex",null,s,ref size)==0?s.ToString():null;}
}
'@
}
function Notify-CallbackAssociation {Initialize-CallbackShell;[ProfileLauncherShell]::Changed()}
function Get-EffectiveCallbackCommand {Initialize-CallbackShell;return [ProfileLauncherShell]::Command()}
function Test-CallbackOwner($Key) {
    try {
        $process=Get-Process -Id ([int]$Key.GetValue('LauncherOwnerPid')) -ErrorAction Stop
        return ($process.StartTime.ToUniversalTime().Ticks.ToString() -ceq [string]$Key.GetValue('LauncherOwnerStart'))
    } catch {return $false}
}
function New-VolatileCallbackKey($Parent,[string]$Name) {
    return $Parent.CreateSubKey($Name,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[Microsoft.Win32.RegistryOptions]::Volatile)
}
function Remove-LauncherCallbackRegistration([string]$Script,[string]$Token='',[switch]$RequireInactive) {
    $path=Get-CallbackProtocolKey;$key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($path,$true)
    if($null -eq $key){return}
    $owner=$null
    try {
        $owner=$key.OpenSubKey('ProfileLauncherOwner',$true)
        if(!$owner -or $owner.GetValue('LauncherScript') -cne $Script){return}
        if($Token -and $owner.GetValue('LauncherToken') -cne $Token){return}
        if($RequireInactive -and (Test-CallbackOwner $owner)){throw 'Exit the launcher before updating or removing callback routing.'}
        $root=[string]$owner.GetValue('LauncherRoot');$keepRoot=($owner.GetValue('LauncherKeepRoot') -eq 1)
        $child=$key.OpenSubKey('shell\open\command',$true)
        try {
            # A command changed by its owner belongs to them. Never overwrite or remove it.
            if($child -and $child.GetValue('') -ceq (Get-CallbackHandlerCommand $root $Script)){$child.DeleteValue('',$false)}
        } finally {if($child){$child.Dispose()}}
        # Delete only empty keys, bottom-up. Extra values/subkeys survive, including concurrent edits.
        foreach($level in @('shell\open\command','shell\open','shell')) {
            $node=$key.OpenSubKey($level);$empty=$false
            try {if($node){$empty=($node.ValueCount -eq 0 -and $node.SubKeyCount -eq 0)}}finally{if($node){$node.Dispose()}}
            if($empty){$key.DeleteSubKey($level,$false)}
        }
        foreach($name in @('LauncherScript','LauncherRoot','LauncherToken','LauncherOwnerPid','LauncherOwnerStart','LauncherKeepRoot')){$owner.DeleteValue($name,$false)}
        $emptyOwner=($owner.SubKeyCount -eq 0 -and $owner.ValueCount -eq 0);$owner.Dispose();$owner=$null
        if($emptyOwner){$key.DeleteSubKey('ProfileLauncherOwner',$false)}
        $removeRoot=(!$keepRoot -and $key.SubKeyCount -eq 0 -and $key.ValueCount -eq 2 -and $key.GetValue('') -ceq 'URL:Profile Launcher' -and $key.GetValue('URL Protocol') -ceq '')
    } finally {if($owner){$owner.Dispose()};$key.Dispose()}
    if($removeRoot){[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($path,$false)}
    Notify-CallbackAssociation
}
function Enable-LauncherCallbackRouting([string]$Root,[string]$Script) {
    $Root=Get-CanonicalRoot $Root;$Script=[IO.Path]::GetFullPath($Script)
    $command=Get-CallbackHandlerCommand $Root $Script
    $mutex=New-Object Threading.Mutex($false,(Get-CallbackRoutingLockName))
    $owned=$false;$token=[guid]::NewGuid().ToString('N')
    try {
        try {$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
        if(!$owned){throw 'Another launcher is already routing browser returns.'}
        Remove-LauncherCallbackRegistration $Script -RequireInactive
        $existing=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((Get-CallbackProtocolKey));$keepRoot=$false
        if($existing){
            try {
                $keepRoot=($existing.SubKeyCount -eq 0 -and $existing.ValueCount -eq 2 -and @($existing.GetValueNames()) -contains '' -and @($existing.GetValueNames()) -contains 'URL Protocol' -and $existing.GetValue('') -is [string] -and $existing.GetValue('URL Protocol') -ceq '')
                if(!$keepRoot){throw 'A custom codex URL handler exists. It was preserved.'}
            } finally {$existing.Dispose()}
        }
        $key=New-VolatileCallbackKey ([Microsoft.Win32.Registry]::CurrentUser) (Get-CallbackProtocolKey)
        try {
            if(!$keepRoot){$key.SetValue('','URL:Profile Launcher');$key.SetValue('URL Protocol','')}
            $owner=New-VolatileCallbackKey $key 'ProfileLauncherOwner'
            try {
                $owner.SetValue('LauncherScript',$Script);$owner.SetValue('LauncherRoot',$Root);$owner.SetValue('LauncherToken',$token)
                $owner.SetValue('LauncherKeepRoot',[int]$keepRoot)
                $owner.SetValue('LauncherOwnerPid',$PID);$owner.SetValue('LauncherOwnerStart',(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks.ToString())
            } finally {$owner.Dispose()}
            $shell=New-VolatileCallbackKey $key 'shell'
            try {$open=New-VolatileCallbackKey $shell 'open';try{$child=New-VolatileCallbackKey $open 'command';try{$child.SetValue('',$command)}finally{$child.Dispose()}}finally{$open.Dispose()}}finally{$shell.Dispose()}
        } finally {$key.Dispose()}
        Notify-CallbackAssociation
        if((Get-EffectiveCallbackCommand) -cne $command){throw 'Windows keeps a different default URL handler. Callback routing was not enabled.'}
        Start-CallbackGuard $Script $token
        return [pscustomobject]@{Script=$Script;Token=$token;Mutex=$mutex;Closed=$false}
    } catch {
        if($owned){try{Remove-LauncherCallbackRegistration $Script $token}finally{$mutex.ReleaseMutex()}}
        $mutex.Dispose();throw
    }
}
function Disable-LauncherCallbackRouting($Registration) {
    if($null -eq $Registration -or $Registration.Closed){return}
    try {Remove-LauncherCallbackRegistration $Registration.Script $Registration.Token}
    finally {$Registration.Mutex.ReleaseMutex();$Registration.Mutex.Dispose();$Registration.Closed=$true}
}
function Start-CallbackGuard([string]$Script,[string]$Token) {
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $guard=Join-Path $PSScriptRoot 'CallbackGuard.ps1'
    $start.Arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$guard+'" "'+$Script+'" "'+$Token+'"'
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $process=[Diagnostics.Process]::Start($start);if($process){$process.Dispose()}
}
function Watch-LauncherCallbackRouting([string]$Script,[string]$Token) {
    while($true) {
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((Get-CallbackProtocolKey)+'\ProfileLauncherOwner')
        if(!$key){return}
        try {if($key.GetValue('LauncherToken') -cne $Token){return};$alive=Test-CallbackOwner $key}finally{$key.Dispose()}
        if(!$alive){break}
        Start-Sleep -Milliseconds 500
    }
    Invoke-LauncherLock (Get-CallbackRoutingLockName) {Remove-LauncherCallbackRegistration $Script $Token -RequireInactive} 0
}
