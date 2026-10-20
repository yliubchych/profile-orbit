param([int]$Count=2,[string]$Output=(Join-Path $PSScriptRoot '.tmp/launcher-preview.png'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
. "$PSScriptRoot/../UI.ps1"
$root=Join-Path $PSScriptRoot ('.tmp/render-'+[guid]::NewGuid().ToString('N'))
$script:RenderStates=@{}
$samples=@(@('Work','#9BE4CC','Open'),@('Personal','#AFCBFF','Background'),@('Client project','#E6C38A','Stopped'),@('Research','#D7B5F5','Unknown'))
for($i=0;$i -lt $Count;$i++){
    $item=$samples[$i%$samples.Count]
    $p=Add-LauncherProfile $root ($item[0]+' '+($i+1)) $item[1]
    $script:RenderStates[$p.Id]=$item[2]
}
function Get-LauncherProfileState($Root,$Id){
    $s=$script:RenderStates[$Id];$action=@{Open='Focus';Background='Reopen';Stopped='Launch';Unknown='Unavailable'}[$s]
    return [pscustomobject]@{Status=$s;Action=$action;WindowCount=0}
}
$f=New-LauncherForm $root
try {
    $f.Tag.EnableHotkeys=$false
    $f.Show();[Windows.Forms.Application]::DoEvents()
    foreach($control in $f.Controls){if($control.Right -gt $f.ClientSize.Width -or $control.Bottom -gt $f.ClientSize.Height){throw 'A control extends beyond the window bounds.'}}
    if($Count -gt 2){
        $cards=@($f.Tag.List.Controls)
        if($cards[0].Top -ne $cards[1].Top){throw 'Profile cards no longer fit two columns with scrolling.'}
    }
    $null=New-Item -ItemType Directory -Path (Split-Path $Output -Parent) -Force
    $bitmap=New-Object Drawing.Bitmap($f.Width,$f.Height)
    try{$f.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$f.Width,$f.Height)));$bitmap.Save($Output,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
    Write-Output ('Rendered '+$Output)
} finally {$f.Dispose()}
