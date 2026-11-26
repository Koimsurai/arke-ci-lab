# Starts Arke (light theme, test profile) and takes screenshots of its window with 24 px around it:
# active, then inactive (Notepad in front, out of the way). Also logs the pixel colours across the
# four edges, so the top line can be compared with DWM's own border on the other three sides.
$ErrorActionPreference = 'Stop'
$out = Join-Path $PWD 'shots'
New-Item -ItemType Directory -Force $out | Out-Null
function Log($m) { Write-Host $m; Add-Content "$out\log.txt" $m }
Log ("OS: " + [Environment]::OSVersion.VersionString + " build " + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct R { public int l, t, r, b; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool p);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out R r, int s);
}
'@
[W]::SetProcessDPIAware() | Out-Null

$p = Join-Path $env:RUNNER_TEMP 'profile'
New-Item -ItemType Directory -Force "$p\Roaming\Arke", "$p\Local" | Out-Null
$settings = @{ whats_new_auto = $false; keep_running = $false; update_auto = $false; open_folders_in_arke = $false
  welcome_seen = $true; theme = 'light'; window = @{ x = 120; y = 120; width = 900; height = 560; maximized = $false } }
[IO.File]::WriteAllText("$p\Roaming\Arke\settings.json", ($settings | ConvertTo-Json -Depth 4))
$env:APPDATA = "$p\Roaming"; $env:LOCALAPPDATA = "$p\Local"
$env:ARKE_NO_FOLDER_HANDLER = '1'; $env:ARKE_UNINSTALL_SANDBOX = '1'; $env:USERNAME = 'arkelab'

$exe = Join-Path $PWD 'target\debug\arke.exe'
$proc = Start-Process $exe 'C:\Windows' -PassThru
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 120 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 500; $proc.Refresh(); $h = $proc.MainWindowHandle }
if ($h -eq [IntPtr]::Zero) { Log 'no Arke window'; exit 1 }
Start-Sleep 6

function Frame { $r = New-Object W+R; [W]::DwmGetWindowAttribute($h, 9, [ref]$r, 16) | Out-Null; $r }
function Shot($name) {
  $r = Frame; $pad = 24
  $x = $r.l - $pad; $y = $r.t - $pad; $w = $r.r - $r.l + 2 * $pad; $hh = $r.b - $r.t + 2 * $pad
  $bmp = New-Object Drawing.Bitmap $w, $hh; $g = [Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size); $bmp.Save("$out\$name.png")
  # Colours across each edge, from outside to inside (pad - 2 .. pad + 3).
  $midX = [int]($w / 2); $midY = [int]($hh / 2)
  $top = ($pad - 2)..($pad + 3) | ForEach-Object { $c = $bmp.GetPixel($midX, $_); '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B }
  $left = ($pad - 2)..($pad + 3) | ForEach-Object { $c = $bmp.GetPixel($_, $midY); '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B }
  $right = ($pad - 2)..($pad + 3) | ForEach-Object { $c = $bmp.GetPixel($w - 1 - $_, $midY); '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B }
  $bottom = ($pad - 2)..($pad + 3) | ForEach-Object { $c = $bmp.GetPixel($midX, $hh - 1 - $_); '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B }
  Log "$name frame $($r.l),$($r.t)-$($r.r),$($r.b)"
  Log "  top    $($top -join ' ')"
  Log "  left   $($left -join ' ')"
  Log "  right  $($right -join ' ')"
  Log "  bottom $($bottom -join ' ')"
  $g.Dispose(); $bmp.Dispose()
}

[W]::SetForegroundWindow($h) | Out-Null; Start-Sleep 2
Shot 'active'
$np = Start-Process notepad -PassThru; Start-Sleep 3; $np.Refresh()
[W]::MoveWindow($np.MainWindowHandle, 1100, 650, 300, 200, $true) | Out-Null
[W]::SetForegroundWindow($np.MainWindowHandle) | Out-Null; Start-Sleep 2
Shot 'inactive'
$full = New-Object Drawing.Bitmap 1280, 900; $g = [Drawing.Graphics]::FromImage($full)
$g.CopyFromScreen(0, 0, 0, 0, $full.Size); $full.Save("$out\full.png"); $g.Dispose(); $full.Dispose()
Stop-Process -Id $np.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Copy-Item "$p\Local\Arke\arke.log" $out -ErrorAction SilentlyContinue
Log 'done'
