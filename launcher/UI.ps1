Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot/Updates.ps1"
$script:LauncherCodeRoot=$PSScriptRoot
[Windows.Forms.Application]::EnableVisualStyles()
$script:Theme = @{ Background='#10151F'; Surface='#202C3D'; Text='#F3F7F8'; Muted='#A6B5C9'; Accent='#9BE4CC' }
if (-not ('LauncherSurface' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
public class LauncherSurface : Panel {
    public LauncherSurface() { DoubleBuffered = true; }
    public static GraphicsPath Shape(Rectangle r, int radius) {
        GraphicsPath p = new GraphicsPath(); int d=radius*2;
        p.AddArc(r.X,r.Y,d,d,180,90); p.AddArc(r.Right-d,r.Y,d,d,270,90);
        p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90); p.AddArc(r.X,r.Bottom-d,d,d,90,90); p.CloseFigure(); return p;
    }
    protected override void OnPaintBackground(PaintEventArgs e) {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.Clear(Parent == null ? BackColor : Parent.BackColor);
        Rectangle r = new Rectangle(1,1,Width-5,Height-7);
        using(GraphicsPath p=Shape(r,16))
        using(GraphicsPath shadow=Shape(new Rectangle(2,5,Width-5,Height-7),16))
        using(Brush shade=new SolidBrush(Color.FromArgb(65,0,0,0)))
        using(Brush fill=new LinearGradientBrush(r,BackColor,Color.FromArgb(23,32,46),65f))
        using(Pen edge=new Pen(Color.FromArgb(58,78,103))) {
            e.Graphics.FillPath(shade,shadow); e.Graphics.FillPath(fill,p); e.Graphics.DrawPath(edge,p);
        }
    }
}
public class LauncherButton : Button {
    bool hover;
    public LauncherButton() { DoubleBuffered=true; }
    protected override void OnMouseEnter(EventArgs e) { hover=true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover=false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
        e.Graphics.Clear(Parent == null ? BackColor : Parent.BackColor);
        Rectangle r=new Rectangle(1,1,Width-3,Height-3);
        Color top=hover ? ControlPaint.Light(BackColor,.15f) : BackColor;
        using(GraphicsPath p=LauncherSurface.Shape(r,9))
        using(Brush b=new LinearGradientBrush(r,top,ControlPaint.Dark(BackColor,.13f),90f))
        using(Pen edge=new Pen(Color.FromArgb(Enabled ? 65 : 25,166,190,210))) {
            e.Graphics.FillPath(b,p); e.Graphics.DrawPath(edge,p);
        }
        TextRenderer.DrawText(e.Graphics,Text,Font,r,Enabled ? ForeColor : Color.FromArgb(116,130,149),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
        if(Focused && ShowFocusCues) ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(5,5,Width-11,Height-11),ForeColor,BackColor);
    }
}
"@
}
function New-UiLabel($Parent, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, [float]$Size=10, [string]$Color='#F3F7F8') {
    $c=New-Object Windows.Forms.Label
    $c.Text=$Text; $c.SetBounds($X,$Y,$Width,$Height)
    $c.AutoEllipsis=$true; $c.BackColor=[Drawing.Color]::Transparent
    $c.Font=New-Object Drawing.Font('Segoe UI',$Size)
    $c.ForeColor=[Drawing.ColorTranslator]::FromHtml($Color)
    $Parent.Controls.Add($c); return $c
}
function New-UiButton($Parent, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, [string]$Back='#2A394E', [string]$Fore='#F3F7F8') {
    $c=New-Object LauncherButton
    $c.Text=$Text; $c.SetBounds($X,$Y,$Width,$Height)
    $c.FlatStyle='Flat'; $c.FlatAppearance.BorderSize=0
    $c.BackColor=[Drawing.ColorTranslator]::FromHtml($Back)
    $c.ForeColor=[Drawing.ColorTranslator]::FromHtml($Fore)
    $c.Cursor=[Windows.Forms.Cursors]::Hand
    $c.UseVisualStyleBackColor=$false
    $Parent.Controls.Add($c); return $c
}
function Show-LauncherError($Form, $ErrorRecord) {
    $Form.Tag.Status.Text='Could not complete this action.'
    try{Write-LauncherEvent $Form.Tag.Root 'launch' 'failed'}catch{}
    [void][Windows.Forms.MessageBox]::Show($Form,$ErrorRecord.Exception.Message,'Profile launcher')
}
function New-ProfileEditor([string]$Root, [string]$Id='') {
    $f=New-Object Windows.Forms.Form
    $f.Text='Set up a profile'; $f.ClientSize=New-Object Drawing.Size(420,240)
    $f.StartPosition='CenterParent'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
    $f.Font=New-Object Drawing.Font('Segoe UI',10)
    $f.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Background)
    $null=New-UiLabel $f 'Profile name' 24 18 370 24
    $name=New-Object Windows.Forms.TextBox; $name.SetBounds(24,46,370,28); $name.MaxLength=60; $f.Controls.Add($name)
    $null=New-UiLabel $f 'Profile color' 24 86 370 24
    $color=New-Object Windows.Forms.ComboBox; $color.SetBounds(24,114,370,30); $color.DropDownStyle='DropDownList'
    $palette=@('#9BE4CC','#AFCBFF','#E6C38A','#D7B5F5','#F0AFAF','#B7D884')
    $f.Controls.Add($color)
    if ($Id) {
        $p=Get-LauncherProfile $Root $Id; $name.Text=$p.Name
        if ($palette -notcontains $p.Color) { $palette+=@($p.Color) }
    }
    foreach($hex in $palette) { [void]$color.Items.Add($hex) }
    $color.SelectedIndex=0
    if ($Id) { $color.SelectedItem=$p.Color }
    $save=New-UiButton $f 'Save profile' 214 174 180 40 $script:Theme.Accent '#101416'
    $cancel=New-UiButton $f 'Cancel' 24 174 170 40
    $cancel.DialogResult='Cancel'; $f.CancelButton=$cancel; $f.AcceptButton=$save
    $f.Tag=@{Root=$Root;Id=$Id;NameBox=$name;ColorBox=$color;SaveButton=$save}
    $save.Add_Click({
        $dialog=$this.FindForm()
        try { Save-ProfileEditor $dialog; $dialog.DialogResult='OK'; $dialog.Close() }
        catch { [void][Windows.Forms.MessageBox]::Show($dialog,$_.Exception.Message,'Check profile details') }
    })
    return $f
}
function Save-ProfileEditor($Editor) {
    $ctx=$Editor.Tag
    if ($ctx.Id) { $null=Update-LauncherProfile $ctx.Root $ctx.Id $ctx.NameBox.Text ([string]$ctx.ColorBox.SelectedItem) }
    else { $null=Add-LauncherProfile $ctx.Root $ctx.NameBox.Text ([string]$ctx.ColorBox.SelectedItem) }
}
function Show-ProfileEditor($Owner, [string]$Id='') {
    $dialog=New-ProfileEditor $Owner.Tag.Root $Id
    try { $null=$dialog.ShowDialog($Owner) } finally { $dialog.Dispose() }
    Update-LauncherCards $Owner
}
function Update-LauncherCards($Form) {
    $ctx=$Form.Tag
    $ctx.List.SuspendLayout()
    try {
        foreach($old in @($ctx.List.Controls)) { $ctx.List.Controls.Remove($old); $old.Dispose() }
        $ctx.Cards=@{}
        $profiles=@(Get-LauncherProfiles $ctx.Root)
        $ctx.EmptyLabel.Visible=($profiles.Count -eq 0)
        $ctx.AllButton.Enabled=($profiles.Count -gt 0 -and !$ctx.LaunchTimer.Enabled)
        $ctx.AllButton.Visible=($profiles.Count -gt 0)
        foreach($p in $profiles) {
            $card=New-Object LauncherSurface
            $card.Size=New-Object Drawing.Size(284,268); $card.Margin=New-Object Windows.Forms.Padding(0,0,20,20)
            $card.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Surface)
            $ctx.List.Controls.Add($card)
            $null=New-UiLabel $card 'PROFILE' 20 16 245 20 8 $p.Color
            $name=New-UiLabel $card $p.Name 20 39 245 34 18
            $name.Font=New-Object Drawing.Font('Segoe UI Semibold',18)
            $stateLabel=New-UiLabel $card 'Checking...' 20 77 245 24 9 $script:Theme.Muted
            $open=New-UiButton $card ('Open '+$p.Name) 20 106 248 40 $p.Color '#101416'; $open.Tag=$p.Id
            $open.Add_Click({
                $owner=$this.FindForm(); $this.Enabled=$false
                try { $null=Start-CodexProfile $this.Tag; $owner.Tag.Status.Text='Profile opened.';try{Write-LauncherEvent $owner.Tag.Root 'launch' 'ok'}catch{} }
                catch { Show-LauncherError $owner $_ }
                finally { $this.Enabled=$true }
                Update-LauncherStatus $owner
            })
            $edit=New-UiButton $card 'Edit profile' 20 158 116 36; $edit.Tag=$p.Id
            $edit.Add_Click({ $owner=$this.FindForm(); try { Show-ProfileEditor $owner $this.Tag } catch { Show-LauncherError $owner $_ } })
            $close=New-UiButton $card 'Fully close' 152 158 116 36; $close.Tag=$p.Id
            $close.Add_Click({
                $owner=$this.FindForm(); $owner.Tag.LaunchTimer.Stop(); $owner.Tag.Pending=@()
                try { $owner.Tag.Status.Text=Stop-CodexProfile $this.Tag;try{Write-LauncherEvent $owner.Tag.Root 'close' 'ok'}catch{} } catch { Show-LauncherError $owner $_ }
                $owner.Tag.AllButton.Enabled=$true
            })
            $projects=New-UiButton $card 'Projects...' 20 210 116 36; $projects.Tag=$p.Id
            $projects.Add_Click({
                $owner=$this.FindForm()
                try { $manager=New-ProjectManager $owner.Tag.Root $this.Tag;try{[void]$manager.ShowDialog($owner)}finally{$manager.Dispose()} }
                catch { Show-LauncherError $owner $_ }
            })
            $plugins=New-UiButton $card 'Plugins...' 152 210 116 36; $plugins.Tag=$p.Id
            $plugins.Add_Click({
                $owner=$this.FindForm();$this.Enabled=$false
                try {Invoke-LauncherPlugins $owner.Tag.Root $this.Tag;$owner.Tag.Status.Text='Plugin directory opened for this profile.'}
                catch {Show-LauncherError $owner $_}
                finally {$this.Enabled=$true}
            })
            $ctx.Cards[$p.Id]=@{Panel=$card;NameLabel=$name;StateLabel=$stateLabel;OpenButton=$open;EditButton=$edit;CloseButton=$close;ProjectsButton=$projects;PluginsButton=$plugins}
        }
    } finally { $ctx.List.ResumeLayout() }
    Update-LauncherStatus $Form
    if($ctx.ContainsKey('TrayMenu')){Update-LauncherTray $Form}
    if($Form.Visible -and $ctx.EnableHotkeys){Update-LauncherHotkeys $Form}
}
function New-DiagnosticsWindow([string]$Root) {
    $report=Get-LauncherDiagnostic $Root
    $f=New-Object Windows.Forms.Form;$f.Text='Diagnostics - local and redacted'
    $f.ClientSize=New-Object Drawing.Size(600,500);$f.StartPosition='CenterParent';$f.Font=New-Object Drawing.Font('Segoe UI',10)
    $f.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Background)
    $null=New-UiLabel $f 'Review this report before sharing it.' 24 16 550 30 13
    $preview=New-Object Windows.Forms.TextBox;$preview.SetBounds(24,58,552,350);$preview.Multiline=$true;$preview.ReadOnly=$true;$preview.ScrollBars='Both'
    $preview.Text=$report|ConvertTo-Json -Depth 10;$f.Controls.Add($preview)
    $export=New-UiButton $f 'Export report...' 24 432 200 42 $script:Theme.Accent '#101416'
    $f.Tag=@{Report=$report;Preview=$preview;ExportButton=$export}
    $export.Add_Click({
        $owner=$this.FindForm();$picker=New-Object Windows.Forms.SaveFileDialog;$picker.Filter='JSON report (*.json)|*.json';$picker.FileName='launcher-diagnostic.json'
        try{if($picker.ShowDialog($owner) -eq 'OK'){Export-LauncherDiagnostic $owner.Tag.Report $picker.FileName}}catch{[void][Windows.Forms.MessageBox]::Show($owner,'Could not save the report. Choose a writable location.','Export failed')}finally{$picker.Dispose()}
    })
    return $f
}
function Update-ProjectList($Manager) {
    $ctx=$Manager.Tag
    $ctx.List.Items.Clear()
    foreach($item in @(Get-LauncherProjects $ctx.Root $ctx.Id)){[void]$ctx.List.Items.Add($item)}
    $ctx.OpenButton.Enabled=($ctx.List.Items.Count -gt 0)
    $ctx.RemoveButton.Enabled=($ctx.List.Items.Count -gt 0)
}
function Open-SelectedProject($Manager) {
    $ctx=$Manager.Tag;$item=$ctx.List.SelectedItem
    if($null -eq $item){throw 'Select a project shortcut first.'}
    Invoke-LauncherProject $ctx.Root $ctx.Id $item.Id
    try{Write-LauncherEvent $ctx.Root 'project' 'ok'}catch{}
}
function New-ProjectManager([string]$Root,[string]$Id) {
    $p=Get-LauncherProfile $Root $Id
    $f=New-Object Windows.Forms.Form;$f.Text='Projects - '+$p.Name
    $f.ClientSize=New-Object Drawing.Size(560,350);$f.StartPosition='CenterParent';$f.FormBorderStyle='FixedDialog';$f.MaximizeBox=$false;$f.MinimizeBox=$false
    $f.Font=New-Object Drawing.Font('Segoe UI',10);$f.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Background)
    $null=New-UiLabel $f ('Open a project using '+$p.Name) 24 18 510 36 14
    $list=New-Object Windows.Forms.ListBox;$list.SetBounds(24,64,512,192);$list.DisplayMember='Name';$f.Controls.Add($list)
    $add=New-UiButton $f '+ Add folder' 24 276 154 40
    $open=New-UiButton $f 'Open selected' 196 276 168 40 $p.Color '#101416'
    $remove=New-UiButton $f 'Remove shortcut' 382 276 154 40
    $f.Tag=@{Root=$Root;Id=$Id;List=$list;OpenButton=$open;RemoveButton=$remove;AddButton=$add}
    $add.Add_Click({
        $owner=$this.FindForm();$picker=New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description='Choose a project folder for this profile';$picker.ShowNewFolderButton=$false
        try { if($picker.ShowDialog($owner) -eq 'OK'){
            $name=Split-Path $picker.SelectedPath -Leaf;if(!$name){$name=$picker.SelectedPath}
            $null=Add-LauncherProject $owner.Tag.Root $owner.Tag.Id $name $picker.SelectedPath
            Update-ProjectList $owner
        }} catch {[void][Windows.Forms.MessageBox]::Show($owner,$_.Exception.Message,'Could not add project')}finally{$picker.Dispose()}
    })
    $open.Add_Click({$owner=$this.FindForm();try{Open-SelectedProject $owner;$owner.Close()}catch{[void][Windows.Forms.MessageBox]::Show($owner,$_.Exception.Message,'Could not open project')}})
    $remove.Add_Click({$owner=$this.FindForm();$item=$owner.Tag.List.SelectedItem;if($null -ne $item){try{Remove-LauncherProject $owner.Tag.Root $owner.Tag.Id $item.Id;Update-ProjectList $owner}catch{[void][Windows.Forms.MessageBox]::Show($owner,$_.Exception.Message,'Could not remove shortcut')}}})
    Update-ProjectList $f
    return $f
}
function Update-LauncherStatus($Form) {
    $ctx=$Form.Tag
    foreach($id in @($ctx.Cards.Keys)) {
        $state=Get-LauncherProfileState $ctx.Root $id
        $card=$ctx.Cards[$id]
        $card.StateLabel.Text=$state.Status
        $stateColor=switch($state.Status){'Open' {'#9BE4CC'} 'Background' {'#AFCBFF'} 'Unknown' {'#E6C38A'} default {'#A6B5C9'}}
        $card.StateLabel.ForeColor=[Drawing.ColorTranslator]::FromHtml($stateColor)
        $card.OpenButton.Text=$state.Action+' '+$card.NameLabel.Text
        $card.OpenButton.Enabled=($state.Action -ne 'Unavailable')
        $card.CloseButton.Enabled=($state.Status -in @('Open','Background'))
        $card.CloseButton.Visible=$card.CloseButton.Enabled
    }
}
function New-LauncherForm([string]$Root) {
    $f=New-Object Windows.Forms.Form
    $f.Text='Profile launcher'; $f.ClientSize=New-Object Drawing.Size(680,650)
    $f.MinimumSize=New-Object Drawing.Size(696,689); $f.StartPosition='CenterScreen'; $f.AutoScaleMode='Dpi'
    $f.Font=New-Object Drawing.Font('Segoe UI',10)
    $f.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Background)
    $null=New-UiLabel $f 'PROFILE LAUNCHER' 32 22 420 25 9 $script:Theme.Accent
    $updates=New-UiButton $f 'Updates' 510 18 120 32
    $updates.Anchor='Top,Right'
    $updates.Add_Click({Show-LauncherUpdates $this.FindForm()})
    $heading=New-UiLabel $f 'A space for every account.' 30 56 620 48 26
    $heading.Font=New-Object Drawing.Font('Segoe UI Semibold',26)
    $null=New-UiLabel $f 'Choose an account, or create a separate profile.' 32 113 600 25 10 $script:Theme.Muted
    $add=New-UiButton $f '+ Add profile' 32 153 174 36 $script:Theme.Accent '#101416'
    $add.Add_Click({ $owner=$this.FindForm(); try { Show-ProfileEditor $owner } catch { Show-LauncherError $owner $_ } })
    $all=New-UiButton $f 'Open all profiles' 224 153 190 36
    $diagnostics=New-UiButton $f 'Diagnostics' 432 153 198 36
    $diagnostics.Add_Click({$owner=$this.FindForm();try{$dialog=New-DiagnosticsWindow $owner.Tag.Root;try{[void]$dialog.ShowDialog($owner)}finally{$dialog.Dispose()}}catch{Show-LauncherError $owner $_}})
    $all.Add_Click({
        $owner=$this.FindForm(); $ctx=$owner.Tag
        try {
            $ctx.Pending=@(Get-LauncherProfiles $ctx.Root | ForEach-Object {$_.Id})
            Invoke-NextProfile $owner
        } catch { Show-LauncherError $owner $_ }
    })
    $list=New-Object Windows.Forms.FlowLayoutPanel
    $list.SetBounds(32,211,630,324); $list.Anchor='Top,Bottom,Left,Right'; $list.AutoScroll=$true
    $f.Controls.Add($list)
    $empty=New-UiLabel $f 'Add your first profile to get started.' 52 250 540 48 14 $script:Theme.Muted
    $status=New-UiLabel $f 'Ready when you are.' 32 555 616 32 10 $script:Theme.Accent; $status.Anchor='Bottom,Left,Right'
    $hint=New-UiLabel $f 'Closes to tray. Ctrl+Alt+Shift+L opens the launcher; +1 through +9 opens profiles.' 32 590 616 20 8 $script:Theme.Muted; $hint.Anchor='Bottom,Left,Right'
    $note=New-UiLabel $f 'Full close interrupts tasks. New profiles need 2.5 GB free RAM.' 32 615 616 25 8 $script:Theme.Muted; $note.Anchor='Bottom,Left,Right'
    $timer=New-Object Windows.Forms.Timer; $timer.Interval=15000
    $timer.Tag=$f
    $timer.Add_Tick({ $this.Stop(); try { Invoke-NextProfile $this.Tag } catch { Show-LauncherError $this.Tag $_ } })
    $statusTimer=New-Object Windows.Forms.Timer; $statusTimer.Interval=3000; $statusTimer.Tag=$f
    $statusTimer.Add_Tick({ try {
        $ctx=$this.Tag.Tag
        if($ctx.Session -and $ctx.Session.FocusEvent.WaitOne(0)){Restore-LauncherWindow $this.Tag}
        Update-LauncherStatus $this.Tag
    } catch { $this.Tag.Tag.Status.Text='Status is unavailable. Refresh after checking profile metadata.' } })
    $f.Tag=@{Root=$Root;Cards=@{};List=$list;EmptyLabel=$empty;Status=$status;AddButton=$add;AllButton=$all;UpdatesButton=$updates;LaunchTimer=$timer;StatusTimer=$statusTimer;Pending=@()}
    $f.Tag.AllowExit=$false;$f.Tag.EnableHotkeys=$true;$f.Tag.HotkeyTargets=@{};$f.Tag.Session=$null
    Initialize-LauncherTray $f
    $f.Add_Shown({$this.Tag.StatusTimer.Start();$this.Tag.TrayIcon.Visible=$true;Update-LauncherHotkeys $this})
    $f.Add_FormClosing({param($sender,$eventArgs) Handle-LauncherClosing $sender $eventArgs})
    $f.Add_Resize({if($this.WindowState -eq 'Minimized'){$this.Hide()}})
    $f.Add_Disposed({$this.Tag.LaunchTimer.Stop();$this.Tag.LaunchTimer.Dispose();$this.Tag.StatusTimer.Stop();$this.Tag.StatusTimer.Dispose()})
    $f.Add_Disposed({Dispose-LauncherDesktop $this})
    Update-LauncherCards $f
    return $f
}
function New-LauncherUpdateDialog($Owner) {
    $f=New-Object Windows.Forms.Form
    $f.Text='Profile Launcher updates';$f.ClientSize=New-Object Drawing.Size(520,290)
    $f.StartPosition='CenterParent';$f.FormBorderStyle='FixedDialog';$f.MaximizeBox=$false;$f.MinimizeBox=$false
    $f.Font=New-Object Drawing.Font('Segoe UI',10);$f.BackColor=[Drawing.ColorTranslator]::FromHtml($script:Theme.Background)
    $version=([IO.File]::ReadAllText((Join-Path $script:LauncherCodeRoot 'VERSION'))).Trim()
    $null=New-UiLabel $f 'Keep your launcher up to date.' 24 20 472 38 19
    $null=New-UiLabel $f ("Installed version: "+$version) 24 66 472 26 10 $script:Theme.Muted
    $message=New-UiLabel $f 'Check for a newer release on GitHub. Your profiles stay on this computer.' 24 108 472 86 11
    $action=New-UiButton $f 'Check for updates' 24 220 290 44 $script:Theme.Accent '#101416'
    $close=New-UiButton $f 'Close' 332 220 164 44;$close.Add_Click({$this.FindForm().Close()})
    $timer=New-Object Windows.Forms.Timer;$timer.Interval=150;$timer.Tag=$f
    $f.Tag=@{Owner=$Owner;Version=$version;Message=$message;Action=$action;Timer=$timer;Job=$null;Update=$null;Mode='Check';CancelRequested=$false;CodeRoot=$script:LauncherCodeRoot}
    $action.Add_Click({Start-LauncherUpdateTask $this.FindForm()})
    $timer.Add_Tick({Receive-LauncherUpdateTask $this.Tag})
    $f.Add_FormClosing({
        param($sender,$args)
        if($sender.Tag.Job){$args.Cancel=$true;$sender.Tag.CancelRequested=$true;$sender.Hide()}
    })
    $f.Add_Disposed({$this.Tag.Timer.Stop();$this.Tag.Timer.Dispose()})
    return $f
}
function Set-LauncherUpdateResult($Dialog,$Update) {
    $ctx=$Dialog.Tag;$ctx.Update=$Update
    if($Update){
        $ctx.Message.Text='Version '+$Update.Version+" is available. Install and restart the launcher; running Codex profiles stay open."
        $ctx.Action.Text='Install and restart';$ctx.Mode='Install'
    }else{
        $ctx.Message.Text='You are up to date. No newer compatible release was found.'
        $ctx.Action.Text='Check again';$ctx.Mode='Check'
    }
    $ctx.Action.Enabled=$true
}
function Start-LauncherUpdateTask($Dialog) {
    $ctx=$Dialog.Tag
    if($ctx.Job){return}
    try{
        if($ctx.Mode -eq 'Install'){
            . (Join-Path $ctx.CodeRoot 'Release.ps1')
            Assert-LauncherUpdateTarget $ctx.CodeRoot
            $ctx.Message.Text='Downloading and verifying the update...'
        }else{$ctx.Message.Text='Checking GitHub releases...'}
        $ctx.Action.Enabled=$false
        $ps=[PowerShell]::Create()
        $null=$ps.AddScript({
            param($codeRoot,$mode,$version,$update)
            $ErrorActionPreference='Stop'
            . (Join-Path $codeRoot 'Core.ps1')
            . (Join-Path $codeRoot 'Release.ps1')
            . (Join-Path $codeRoot 'Updates.ps1')
            if($mode -eq 'Install'){
                Save-LauncherUpdate $update (Join-Path $env:LOCALAPPDATA 'ProfileLauncherUpdates')
            }else{Get-LauncherUpdate $version}
        }).AddArgument($ctx.CodeRoot).AddArgument($ctx.Mode).AddArgument($ctx.Version).AddArgument($ctx.Update)
        $handle=$ps.BeginInvoke()
        $ctx.Job=@{PowerShell=$ps;Handle=$handle}
        $ctx.Timer.Start()
    }catch{
        if($ps){$ps.Dispose()}
        $ctx.Message.Text=$_.Exception.Message;$ctx.Action.Enabled=$true
    }
}
function Receive-LauncherUpdateTask($Dialog) {
    $ctx=$Dialog.Tag;$job=$ctx.Job
    if(!$job -or !$job.Handle.IsCompleted){return}
    $ctx.Timer.Stop()
    try{
        $result=@($job.PowerShell.EndInvoke($job.Handle))
        if($job.PowerShell.HadErrors){throw ([string]$job.PowerShell.Streams.Error[0])}
        $ctx.Job=$null
        if($ctx.CancelRequested){return}
        if($ctx.Mode -eq 'Install'){
            if($result.Count -ne 1){throw 'The update could not be prepared.'}
            . (Join-Path $ctx.CodeRoot 'Release.ps1')
            Start-LauncherUpdateInstall $result[0] $ctx.CodeRoot $ctx.Owner.Tag.Root
            $ctx.Owner.Tag.AllowExit=$true;$ctx.Owner.Tag.Pending=@();$ctx.Owner.Tag.LaunchTimer.Stop()
            $ctx.Owner.Close()
            $Dialog.Close()
        }else{
            $update=$null;if($result.Count){$update=$result[-1]}
            Set-LauncherUpdateResult $Dialog $update
        }
    }catch{
        $ctx.Message.Text=$_.Exception.Message;$ctx.Action.Enabled=$true
    }finally{
        $job.PowerShell.Dispose();$ctx.Job=$null
        if($ctx.CancelRequested){$Dialog.Close()}
    }
}
function Show-LauncherUpdates($Owner) {
    $dialog=New-LauncherUpdateDialog $Owner
    $dialog.Add_Shown({Start-LauncherUpdateTask $this})
    try{[void]$dialog.ShowDialog($Owner)}finally{if(!$dialog.Tag.Job){$dialog.Dispose()}}
}
function Restore-LauncherWindow($Form) {
    $Form.Show();$Form.WindowState='Normal';[void]$Form.Activate()
}
function Handle-LauncherClosing($Form,$EventArgs) {
    if(!$Form.Tag.AllowExit -and $EventArgs.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
        $EventArgs.Cancel=$true;$Form.Tag.TrayIcon.Visible=$true;$Form.Hide()
    }
}
function Update-LauncherTray($Form) {
    $ctx=$Form.Tag;$menu=$ctx.TrayMenu
    foreach($old in @($menu.Items)){$menu.Items.Remove($old);$old.Dispose()}
    $show=$menu.Items.Add('Open launcher');$show.Add_Click({Restore-LauncherWindow $this.Owner.Tag})
    [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
    foreach($p in @(Get-LauncherProfiles $ctx.Root)){
        $state=Get-LauncherProfileState $ctx.Root $p.Id
        $item=$menu.Items.Add($state.Action+' '+$p.Name);$item.Tag=$p.Id;$item.Enabled=($state.Action -ne 'Unavailable')
        $item.Add_Click({$owner=$this.Owner.Tag;try{$null=Start-CodexProfile $this.Tag;Update-LauncherStatus $owner}catch{Show-LauncherError $owner $_}})
    }
    [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
    $keys=$menu.Items.Add('Global hotkeys');$keys.Checked=$ctx.EnableHotkeys;$keys.CheckOnClick=$true
    $keys.Add_Click({$owner=$this.Owner.Tag;$owner.Tag.EnableHotkeys=$this.Checked;Update-LauncherHotkeys $owner})
    $updates=$menu.Items.Add('Check for updates...')
    $updates.Add_Click({Show-LauncherUpdates $this.Owner.Tag})
    $exit=$menu.Items.Add('Exit launcher');$ctx.ExitItem=$exit
    $exit.Add_Click({$owner=$this.Owner.Tag;$owner.Tag.AllowExit=$true;$owner.Tag.Pending=@();$owner.Tag.LaunchTimer.Stop();$owner.Close()})
}
function Initialize-LauncherTray($Form) {
    $menu=New-Object Windows.Forms.ContextMenuStrip;$menu.Tag=$Form
    $icon=New-Object Windows.Forms.NotifyIcon;$icon.Icon=[Drawing.SystemIcons]::Application;$icon.Text='Profile launcher';$icon.ContextMenuStrip=$menu
    $icon.Tag=$Form;$icon.Add_DoubleClick({Restore-LauncherWindow $this.Tag})
    $menu.Add_Opening({Update-LauncherTray $this.Tag})
    $Form.Tag.TrayMenu=$menu;$Form.Tag.TrayIcon=$icon
}
function Update-LauncherHotkeys($Form) {
    $ctx=$Form.Tag
    if($ctx.Hotkeys){$ctx.Hotkeys.Dispose();$ctx.Hotkeys=$null}
    $ctx.HotkeyTargets=@{}
    if(!$ctx.EnableHotkeys){return}
    try {
        Initialize-LauncherHotkeys
        $registry=New-Object LauncherHotkeyWindow;$registry.Context=$Form
        $registry.Add_Pressed({param($sender,$eventArgs) Invoke-LauncherHotkey $sender.Context $eventArgs.Id})
        $ctx.Hotkeys=$registry;$failures=0
        foreach($key in @(Get-LauncherHotkeyDefinitions $ctx.Root)) {
            if($registry.Register($key.Id,$key.Key)){$ctx.HotkeyTargets[$key.Id]=$key.Target}else{$failures++}
        }
        if($failures){$ctx.Status.Text='Some hotkeys are used by another app. Tray actions remain available.'}
    } catch {$ctx.Status.Text='Global hotkeys are unavailable. Use the launcher or tray menu.'}
}
function Invoke-LauncherHotkey($Form,[int]$Id) {
    $target=$Form.Tag.HotkeyTargets[$Id]
    if(!$target){return}
    if($target -eq 'launcher'){Restore-LauncherWindow $Form;return}
    try{$null=Start-CodexProfile $target;Update-LauncherStatus $Form}catch{Show-LauncherError $Form $_}
}
function Dispose-LauncherDesktop($Form) {
    $ctx=$Form.Tag
    if($ctx.Hotkeys){$ctx.Hotkeys.Dispose();$ctx.Hotkeys=$null}
    $ctx.TrayIcon.Visible=$false;$ctx.TrayIcon.Dispose();$ctx.TrayMenu.Dispose()
}
function Invoke-NextProfile($Form) {
    $ctx=$Form.Tag
    try {
        if ($ctx.Pending.Count -gt 0) {
            $id=$ctx.Pending[0]; $ctx.Pending=@($ctx.Pending | Select-Object -Skip 1)
            $ctx.AllButton.Enabled=$false
            $null=Start-CodexProfile $id
            Update-LauncherStatus $Form
            $ctx.Status.Text='Profile opened. Remaining profiles open 15 seconds apart.'
            if ($ctx.Pending.Count -gt 0) { $ctx.LaunchTimer.Start() }
        }
    } catch { $ctx.Pending=@(); throw }
    finally { if ($ctx.Pending.Count -eq 0) { $ctx.LaunchTimer.Stop(); $ctx.AllButton.Enabled=$true } }
}
