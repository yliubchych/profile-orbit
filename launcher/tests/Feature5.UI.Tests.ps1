. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
function Get-LauncherProfileState {param($Root,$Id) [pscustomobject]@{Status='Stopped';Action='Launch';WindowCount=0}}
function Start-CodexProfile($Name){$script:Opened=$Name}
function Stop-CodexProfile {throw 'Tray/window exit must not stop Codex'}
Test-Case 'Tray menu exposes current profile actions and always has explicit Exit' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC';$f=New-LauncherForm $root
    try {
        Update-LauncherTray $f
        Assert-True ($null -ne $f.Tag.TrayIcon)
        Assert-True (@($f.Tag.TrayMenu.Items|Where-Object {$_.Text -eq 'Exit launcher'}).Count -eq 1)
        $item=@($f.Tag.TrayMenu.Items|Where-Object {$_.Tag -eq $p.Id})[0]
        $item.PerformClick();Assert-Equal $p.Id $script:Opened
        Assert-True $f.Tag.ExitItem.Enabled
    } finally {$f.Dispose()}
}
Test-Case 'Hotkey routing opens selected profile, while close-to-tray preserves all tasks' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC';$f=New-LauncherForm $root
    try {
        $f.Tag.HotkeyTargets=@{10=$p.Id}
        Invoke-LauncherHotkey $f 10
        Assert-Equal $p.Id $script:Opened
        $args=New-Object Windows.Forms.FormClosingEventArgs([Windows.Forms.CloseReason]::UserClosing,$false)
        Handle-LauncherClosing $f $args
        Assert-True $args.Cancel
        $f.Tag.AllowExit=$true
        $args=New-Object Windows.Forms.FormClosingEventArgs([Windows.Forms.CloseReason]::UserClosing,$false)
        Handle-LauncherClosing $f $args
        Assert-Equal $false $args.Cancel
    } finally {$f.Dispose()}
}
Test-Case 'Repeated tray refresh does not accumulate duplicate menu items' {
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC';$f=New-LauncherForm $root
    try{Update-LauncherTray $f;$count=$f.Tag.TrayMenu.Items.Count;Update-LauncherTray $f;Assert-Equal $count $f.Tag.TrayMenu.Items.Count}
    finally{$f.Dispose()}
}
Test-Case 'Native global hotkey registration detects conflicts and releases registrations' {
    Initialize-LauncherHotkeys
    $a=New-Object LauncherHotkeyWindow;$b=New-Object LauncherHotkeyWindow
    try {
        # Ctrl+Alt+Shift+F24, not an emitted keyboard event.
        Assert-True ($a.Register(777,135))
        Assert-Equal $false ($b.Register(778,135))
        $a.Dispose()
        Assert-True ($b.Register(778,135))
    } finally {$a.Dispose();$b.Dispose()}
}
Test-Case 'Native hotkey message reaches its profile action through the production event handler' {
    Add-Type @'
using System;using System.Runtime.InteropServices;
public static class SyntheticHotkeyMessage {
 [DllImport("user32.dll")]public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
}
'@
    $root=New-TestRoot;$p=Add-LauncherProfile $root 'Work' '#9BE4CC';$f=New-LauncherForm $root
    try {
        Update-LauncherHotkeys $f
        Assert-True ($null -ne $f.Tag.Hotkeys)
        $f.Tag.HotkeyTargets[10]=$p.Id;$script:Opened=''
        $null=[SyntheticHotkeyMessage]::PostMessage($f.Tag.Hotkeys.Handle,0x0312,[IntPtr]10,[IntPtr]::Zero)
        [Windows.Forms.Application]::DoEvents()
        Assert-Equal $p.Id $script:Opened
    } finally {$f.Dispose()}
}
Test-Case 'Open-all timer advances in profile order and explicit Exit cancels pending launches' {
    $root=New-TestRoot;$a=Add-LauncherProfile $root 'Work' '#9BE4CC';$b=Add-LauncherProfile $root 'Home' '#AFCBFF'
    $f=New-LauncherForm $root
    try {
        $f.Tag.Pending=@($a.Id,$b.Id)
        Invoke-NextProfile $f
        Assert-Equal $a.Id $script:Opened
        Assert-True $f.Tag.LaunchTimer.Enabled
        $tick=$f.Tag.LaunchTimer.GetType().GetMethod('OnTick',[Reflection.BindingFlags]'Instance,NonPublic')
        $null=$tick.Invoke($f.Tag.LaunchTimer,@([EventArgs]::Empty))
        Assert-Equal $b.Id $script:Opened
        Assert-Equal $false $f.Tag.LaunchTimer.Enabled
        $f.Tag.Pending=@($a.Id,$b.Id);Invoke-NextProfile $f
        Update-LauncherTray $f
        $f.Tag.ExitItem.PerformClick()
        Assert-True $f.Tag.AllowExit
        Assert-Equal 0 $f.Tag.Pending.Count
    } finally {$f.Dispose()}
}
Test-Case 'Focus event restores the hidden launcher through its status timer' {
    $root=New-TestRoot;$f=New-LauncherForm $root;$session=New-LauncherSession $root
    try {
        $f.Tag.EnableHotkeys=$false;$f.Tag.Session=$session
        $null=$f.Handle;$f.Hide()
        $null=$session.FocusEvent.Set()
        $tick=$f.Tag.StatusTimer.GetType().GetMethod('OnTick',[Reflection.BindingFlags]'Instance,NonPublic')
        $null=$tick.Invoke($f.Tag.StatusTimer,@([EventArgs]::Empty))
        Assert-True $f.Visible
        Assert-Equal ([Windows.Forms.FormWindowState]::Normal) $f.WindowState
    } finally {$f.Dispose();Close-LauncherSession $session}
}
Complete-Tests
