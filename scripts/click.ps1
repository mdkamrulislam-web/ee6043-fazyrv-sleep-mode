# click.ps1 <x> <y> <double:0/1> [keys] - clicks at physical screen pixels in the Vivado window, then optional SendKeys
param([int]$x, [int]$y, [int]$dbl = 0, [string]$keys = "")
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class M { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(int f, int dx, int dy, int d, int e);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[M]::SetProcessDPIAware() | Out-Null
[M]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 200
$n = 1; if ($dbl -eq 1) { $n = 2 }
for ($i = 0; $i -lt $n; $i++) { [M]::mouse_event(2,0,0,0,0); [M]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 80 }
Start-Sleep -Milliseconds 800
if ($keys -ne "") { [System.Windows.Forms.SendKeys]::SendWait($keys); Start-Sleep -Milliseconds 800 }
