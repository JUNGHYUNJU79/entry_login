# =====================================================================
#  하원초 6학년 엔트리 자동 로그인 - 학생 컴퓨터 1회 설치 스크립트
#  - 확장 프로그램 폴더를 이 컴퓨터(내 문서 아래)에 복사하고
#  - 설치된 브라우저(크롬 / 웨일 / 엣지)마다 확장 프로그램 페이지를 열어
#    개발자 모드 켜기 -> 압축해제된 확장 프로그램 로드 -> 폴더 선택 을 자동으로 눌러 줍니다.
#  Windows PowerShell 5.1 이상에서 동작합니다. (설치.bat 으로 실행하세요)
# =====================================================================
param([switch]$NoPause)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class HwWin32 {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int n);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
}
"@

$AE = [System.Windows.Automation.AutomationElement]
$CT = [System.Windows.Automation.ControlType]
$TS = [System.Windows.Automation.TreeScope]
$TC = [System.Windows.Automation.Condition]::TrueCondition
$ExtName = "하원초 6학년 엔트리 자동 로그인"

function Log($m) { Write-Host ("  " + $m) }
function Ok($m)  { Write-Host ("  [OK] " + $m) -ForegroundColor Green }
function Warn($m){ Write-Host ("  [!] " + $m) -ForegroundColor Yellow }

# ---------- 1. 확장 프로그램 폴더 복사 ----------
$src = Join-Path $PSScriptRoot "chrome_extension"
if (-not (Test-Path (Join-Path $src "manifest.json"))) { throw "chrome_extension 폴더를 찾을 수 없습니다. 압축을 전부 푼 뒤 설치.bat 을 실행해 주세요." }
$dest = Join-Path $env:LOCALAPPDATA "HawonEntryLogin\chrome_extension"
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse $src $dest
Ok ("확장 프로그램을 복사했습니다: " + $dest)

# ---------- UI 자동화 도우미 ----------
function Find-Desc($root, [string]$pattern, $controlType, $timeoutSec) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    $cond = $TC
    if ($controlType) { $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $controlType) }
    foreach ($e in $root.FindAll($TS::Descendants, $cond)) {
      $n = $e.Current.Name
      if ($n -and $n -match $pattern) { return $e }
    }
    Start-Sleep -Milliseconds 500
  }
  return $null
}
function Find-TopWindow([string]$pattern, [int]$pid, $timeoutSec) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    foreach ($w in $AE::RootElement.FindAll($TS::Children, $TC)) {
      if ($w.Current.Name -match $pattern -and ($pid -eq 0 -or $w.Current.ProcessId -eq $pid)) { return $w }
    }
    Start-Sleep -Milliseconds 500
  }
  return $null
}
function Find-Dialog($win) {
  $d = $win.FindAll($TS::Children, $TC) | Where-Object { $_.Current.ClassName -eq "#32770" } | Select-Object -First 1
  if (-not $d) { $d = $AE::RootElement.FindAll($TS::Children, $TC) | Where-Object { $_.Current.ClassName -eq "#32770" -and $_.Current.ProcessId -eq $win.Current.ProcessId } | Select-Object -First 1 }
  return $d
}
function Get-ChildControls([IntPtr]$hwnd) {
  $list = New-Object System.Collections.ArrayList
  $cb = [HwWin32+EnumProc]{ param($h, $l)
    $c = New-Object System.Text.StringBuilder 256; [HwWin32]::GetClassName($h, $c, 256) | Out-Null
    $t = New-Object System.Text.StringBuilder 512; [HwWin32]::GetWindowText($h, $t, 512) | Out-Null
    [void]$list.Add([pscustomobject]@{ h = $h; cls = $c.ToString(); id = [HwWin32]::GetDlgCtrlID($h); text = $t.ToString() }); $true }
  [HwWin32]::EnumChildWindows($hwnd, $cb, [IntPtr]::Zero) | Out-Null
  return $list
}

function Install-Into($name, $exe, $extUrl, $titlePattern) {
  Write-Host ""
  Write-Host ("▶ " + $name + " 에 설치합니다...") -ForegroundColor Cyan
  if (-not (Test-Path $exe)) { Log ($name + " 이(가) 설치되어 있지 않아 건너뜁니다."); return "skip" }

  # 새 창 열기 (이미 켜져 있으면 새 창이 하나 더 열립니다)
  $p = Start-Process $exe -ArgumentList @("--new-window", "about:blank") -PassThru
  Start-Sleep -Seconds 3
  $win = Find-TopWindow ("about:blank|새 탭|New Tab|" + $titlePattern) 0 15
  if (-not $win) { Warn "브라우저 창을 찾지 못했습니다."; return "fail" }

  # 주소창에 확장 프로그램 페이지 주소 입력
  $omni = Find-Desc $win "(주소|Address)" $CT::Edit 10
  if (-not $omni) { Warn "주소창을 찾지 못했습니다."; return "fail" }
  $hwnd = [IntPtr]$win.Current.NativeWindowHandle
  [HwWin32]::ShowWindowAsync($hwnd, 9) | Out-Null
  [HwWin32]::SetForegroundWindow($hwnd) | Out-Null
  Start-Sleep -Milliseconds 600
  $omni.SetFocus(); Start-Sleep -Milliseconds 300
  $omni.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($extUrl)
  Start-Sleep -Milliseconds 300
  if ([HwWin32]::GetForegroundWindow() -ne $hwnd) { Warn "브라우저 창이 맨 앞에 있지 않아 중단합니다. 다른 창을 건드리지 말고 다시 실행해 주세요."; return "fail" }
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  $win = Find-TopWindow $titlePattern $p.Id 15
  if (-not $win) { $win = Find-TopWindow $titlePattern 0 5 }
  if (-not $win) { Warn "확장 프로그램 페이지가 열리지 않았습니다."; return "fail" }
  Log "확장 프로그램 페이지를 열었습니다."

  # 개발자 모드 켜기
  $dev = Find-Desc $win "^(개발자 모드|Developer mode)$" $CT::Button 20
  if (-not $dev) { $dev = Find-Desc $win "^(개발자 모드|Developer mode)$" $CT::CheckBox 3 }
  if (-not $dev) { Warn "개발자 모드 스위치를 찾지 못했습니다."; return "fail" }
  $tp = $dev.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
  if ($tp.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On) { $tp.Toggle(); Start-Sleep -Milliseconds 800 }
  Log "개발자 모드를 켰습니다."

  # 이미 설치되어 있으면 통과
  if (Find-Desc $win $ExtName $null 2) { Ok "이미 설치되어 있습니다."; return "ok" }

  # 압축해제된 확장 프로그램 로드
  $load = Find-Desc $win "(압축해제된 확장 프로그램|압축 풀린 확장|압축을 푼 확장|Load unpacked)" $CT::Button 15
  if (-not $load) { Warn "'압축해제된 확장 프로그램 로드' 버튼을 찾지 못했습니다."; return "fail" }
  try { $load.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke() } catch { }
  $dlg = $null
  for ($i = 0; $i -lt 30 -and -not $dlg; $i++) { Start-Sleep -Milliseconds 500; $dlg = Find-Dialog $win }
  if (-not $dlg) { Warn "폴더 선택 창이 열리지 않았습니다."; return "fail" }
  Start-Sleep -Milliseconds 800
  $hDlg = [IntPtr]$dlg.Current.NativeWindowHandle

  # 폴더 선택 창: 주소줄(Alt+D)에 경로 붙여넣기 -> Enter -> [폴더 선택]
  $saved = $null; try { $saved = [System.Windows.Forms.Clipboard]::GetText() } catch { }
  [System.Windows.Forms.Clipboard]::SetText($dest)
  [HwWin32]::SetForegroundWindow($hDlg) | Out-Null; Start-Sleep -Milliseconds 600
  if ([HwWin32]::GetForegroundWindow() -ne $hDlg) { Warn "폴더 선택 창이 맨 앞에 있지 않아 중단합니다."; return "fail" }
  [System.Windows.Forms.SendKeys]::SendWait("%d"); Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait("^a^v"); Start-Sleep -Milliseconds 300
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}"); Start-Sleep -Milliseconds 1200
  if ($saved) { try { [System.Windows.Forms.Clipboard]::SetText($saved) } catch { } } else { try { [System.Windows.Forms.Clipboard]::Clear() } catch { } }
  $ctrls = Get-ChildControls $hDlg
  $addr = $ctrls | Where-Object { $_.text -like "*chrome_extension*" } | Select-Object -First 1
  if (-not $addr) { Warn "폴더로 이동하지 못했습니다. 열려 있는 창에서 직접 폴더를 골라 주세요: $dest"; return "fail" }
  $ok = $ctrls | Where-Object { $_.cls -eq "Button" -and $_.id -eq 1 } | Select-Object -First 1
  if (-not $ok) { Warn "'폴더 선택' 버튼을 찾지 못했습니다."; return "fail" }
  [HwWin32]::SendMessage($ok.h, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
  Start-Sleep -Seconds 3

  if (Find-Desc $win $ExtName $null 15) { Ok ($name + " 설치 완료!"); return "ok" }
  Warn "설치 결과를 확인하지 못했습니다. 브라우저의 확장 프로그램 목록을 확인해 주세요."
  return "fail"
}

$pf86 = ${env:ProgramFiles(x86)}; if (-not $pf86) { $pf86 = $env:ProgramFiles }
$targets = @(
  @{ name = "크롬(Chrome)"; exes = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$pf86\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"); url = "chrome://extensions/"; title = "^(확장 프로그램|Extensions) - .*Chrome$" },
  @{ name = "웨일(Whale)";  exes = @("$env:ProgramFiles\Naver\Naver Whale\Application\whale.exe", "$pf86\Naver\Naver Whale\Application\whale.exe", "$env:LOCALAPPDATA\Naver\Naver Whale\Application\whale.exe"); url = "whale://extensions/"; title = "^(확장 프로그램|확장앱|Extensions) - .*Whale$" },
  @{ name = "엣지(Edge)";   exes = @("$pf86\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"); url = "edge://extensions/"; title = "^(확장|확장 프로그램|Extensions) .*Edge$" }
)

$results = @()
foreach ($t in $targets) {
  $exe = $t.exes | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $exe) { $exe = $t.exes[0] }
  try { $r = Install-Into $t.name $exe $t.url $t.title } catch { Warn ("오류: " + $_.Exception.Message); $r = "fail" }
  $results += [pscustomobject]@{ 브라우저 = $t.name; 결과 = $r }
}

Write-Host ""
Write-Host "================ 설치 결과 ================" -ForegroundColor Cyan
foreach ($r in $results) {
  $txt = switch ($r.결과) { "ok" { "설치됨" } "skip" { "브라우저 없음(건너뜀)" } default { "실패 - 설명서의 '방법 2'대로 직접 설치해 주세요" } }
  Write-Host ("  " + $r.브라우저 + " : " + $txt)
}
Write-Host ""
Write-Host "  설치된 브라우저에서 엔트리 로그인 화면(playentry.org/signin)을 열면 번호판이 보이고,"
Write-Host "  포털에서 번호 카드를 누르면 아이디/비밀번호가 자동 입력됩니다."
Write-Host ("  ※ 확장 프로그램 폴더 위치: " + $dest + "  (이 폴더를 지우면 작동이 멈춥니다)")
if (-not $NoPause) { Write-Host ""; Read-Host "아무 키나 누르면 창이 닫힙니다" | Out-Null }
