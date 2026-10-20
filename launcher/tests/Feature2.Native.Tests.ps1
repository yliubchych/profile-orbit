. "$PSScriptRoot/TestHarness.ps1"
. "$PSScriptRoot/../Core.ps1"
. "$PSScriptRoot/../Windows.ps1"
Add-Type @"
using System;using System.Runtime.InteropServices;
public static class SyntheticDesktopWindow {
 delegate IntPtr Proc(IntPtr h,uint m,IntPtr w,IntPtr l);
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct WC {public uint style;public Proc proc;public int clsExtra;public int wndExtra;public IntPtr instance;public IntPtr icon;public IntPtr cursor;public IntPtr background;public string menu;public string name;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern ushort RegisterClass(ref WC w);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr CreateWindowEx(uint ex,string cls,string title,uint style,int x,int y,int width,int height,IntPtr parent,IntPtr menu,IntPtr instance,IntPtr param);
 [DllImport("user32.dll")]static extern IntPtr DefWindowProc(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern IntPtr GetModuleHandle(string n);
 [DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int cmd);
 [DllImport("user32.dll")]public static extern bool DestroyWindow(IntPtr h);
 static Proc callback=DefWindowProc;
 public static IntPtr Create(){var wc=new WC{proc=callback,instance=GetModuleHandle(null),name="Chrome_WidgetWin_1"};RegisterClass(ref wc);return CreateWindowEx(0,"Chrome_WidgetWin_1","Synthetic test window",0x00CF0000,0,0,160,100,IntPtr.Zero,IntPtr.Zero,wc.instance,IntPtr.Zero);}
}
"@
Test-Case 'Native enumeration excludes hidden Electron windows and includes visible/minimized windows' {
    $window=[SyntheticDesktopWindow]::Create()
    try {
        Assert-True ($window -ne [IntPtr]::Zero)
        Assert-Equal ([IntPtr]::Zero) (Get-ProfileWindow $PID)
        $null=[SyntheticDesktopWindow]::ShowWindow($window,4)
        Assert-Equal $window (Get-ProfileWindow $PID)
        $null=[SyntheticDesktopWindow]::ShowWindow($window,6)
        Assert-Equal $window (Get-ProfileWindow $PID)
        $null=[SyntheticDesktopWindow]::ShowWindow($window,0)
        Assert-Equal ([IntPtr]::Zero) (Get-ProfileWindow $PID)
    } finally {$null=[SyntheticDesktopWindow]::DestroyWindow($window)}
}
Complete-Tests
