# capture.ps1 <out.png> [delay_s] - screenshot of the Vivado window (falls back to the whole primary screen)
param([string]$out, [int]$delay = 3)
Start-Sleep -Seconds $delay
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 public struct RECT { public int L, T, R, B; } }
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process | Where-Object { $_.MainWindowTitle -like "*Vivado*" } | Select-Object -First 1
if ($p) {
  [W]::ShowWindow($p.MainWindowHandle, 3) | Out-Null   # maximise
  [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 800
  $r = New-Object W+RECT; [W]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $x=[Math]::Max($r.L,0); $y=[Math]::Max($r.T,0); $w=$r.R-$x; $h=$r.B-$y
} else { $b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $x=$b.X;$y=$b.Y;$w=$b.Width;$h=$b.Height }
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"saved $out ${w}x$h"
