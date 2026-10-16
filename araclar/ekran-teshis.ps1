# Ekran / ekran kartı teşhis raporu — hiçbir ayarı DEĞİŞTİRMEZ, sadece okur.
# Sonuç masaüstüne "ekran-raporu.txt" olarak kaydedilir ve panoya kopyalanır.
param([switch]$Beklemeden)
$ErrorActionPreference = 'SilentlyContinue'
$r = New-Object System.Collections.Generic.List[string]
function Ekle($s) { $r.Add($s) }

Ekle "=== EKRAN TESHIS RAPORU — $(Get-Date -Format 'dd.MM.yyyy HH:mm') ==="
$os = Get-CimInstance Win32_OperatingSystem
$pc = Get-CimInstance Win32_ComputerSystem
Ekle "Bilgisayar: $($pc.Manufacturer) $($pc.Model)"
Ekle "Windows: $($os.Caption) $($os.Version)"
Ekle ""

Ekle "--- EKRAN KARTI ---"
foreach ($g in Get-CimInstance Win32_VideoController) {
  Ekle "Kart: $($g.Name)"
  Ekle "  Sürücü: $($g.DriverVersion)  Tarih: $(if ($g.DriverDate) { $g.DriverDate.ToString('dd.MM.yyyy') })"
  Ekle "  Su anki cozunurluk: $($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)  @ $($g.CurrentRefreshRate) Hz  ($($g.CurrentBitsPerPixel) bit)"
  Ekle "  Durum: $($g.Status)  Hata kodu: $($g.ConfigManagerErrorCode)"
  if ($g.Name -match 'Basic Display|Temel Görüntü|Microsoft Basic') { Ekle "  !!! SURUCU YUKLU DEGIL — Windows genel surucusu kullaniliyor" }
}
Ekle ""

Ekle "--- MONITORLER ---"
$baglanti = @{ -2='Bilinmiyor'; -1='Diger'; 0='VGA (analog!)'; 1='S-Video'; 2='Kompozit'; 4='DVI'; 5='HDMI'; 6='MDDI'; 10='DisplayPort'; 11='DisplayPort (dahili)'; 2147483648='Dahili ekran (laptop)' }
$adlar = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
$baglar = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams
$modlar = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorListedSupportedSourceModes
foreach ($m in $adlar) {
  $ad = ([System.Text.Encoding]::ASCII.GetString(($m.UserFriendlyName | Where-Object { $_ -ne 0 })))
  $ure = ([System.Text.Encoding]::ASCII.GetString(($m.ManufacturerName | Where-Object { $_ -ne 0 })))
  Ekle "Monitor: $ure $ad"
  $b = $baglar | Where-Object { $_.InstanceName -eq $m.InstanceName }
  if ($b) { Ekle "  Kablo/baglanti: $($baglanti[[long]$b.VideoOutputTechnology])" }
  $md = $modlar | Where-Object { $_.InstanceName -eq $m.InstanceName }
  if ($md) {
    $en = $md.MonitorSourceModes | Sort-Object { $_.HorizontalActivePixels * $_.VerticalActivePixels } -Descending | Select-Object -First 1
    if ($en) { Ekle "  Monitorun en yuksek (dogal) cozunurlugu: $($en.HorizontalActivePixels) x $($en.VerticalActivePixels)" }
    $hz = ($md.MonitorSourceModes | ForEach-Object { [math]::Round($_.VerticalRefreshRateNumerator / [math]::Max(1,$_.VerticalRefreshRateDenominator)) } | Sort-Object -Unique) -join ', '
    if ($hz) { Ekle "  Destekledigi yenileme hizlari (Hz): $hz" }
  }
}
Ekle ""

Ekle "--- OLCEKLENDIRME (DPI) ---"
Add-Type -AssemblyName System.Windows.Forms
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
  Ekle "Ekran $($s.DeviceName): $($s.Bounds.Width) x $($s.Bounds.Height)  birincil=$($s.Primary)"
}
$dpi = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name AppliedDPI).AppliedDPI
if ($dpi) { Ekle "Olcek: %$([math]::Round($dpi / 96 * 100))" }
$ct = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name FontSmoothingType).FontSmoothingType
Ekle "ClearType (yazi yumusatma): $(if ($ct -eq 2) { 'acik' } else { 'KAPALI' })"
Ekle ""

Ekle "--- SORUNLU AYGITLAR ---"
$sorunlu = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
if ($sorunlu) { $sorunlu | ForEach-Object { Ekle "  $($_.Name)  (hata kodu $($_.ConfigManagerErrorCode))" } } else { Ekle "  Yok" }
Ekle ""
Ekle "--- WINDOWS UPDATE: bekleyen surucu guncellemeleri ---"
try {
  $ara = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'")
  if ($ara.Updates.Count) { foreach ($u in $ara.Updates) { Ekle "  $($u.Title)" } } else { Ekle "  Yok" }
} catch { Ekle "  Kontrol edilemedi" }

$yol = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ekran-raporu.txt'
$r | Out-File -FilePath $yol -Encoding UTF8
$r -join "`r`n" | Set-Clipboard
$r | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Rapor masaustune kaydedildi ve panoya kopyalandi: $yol" -ForegroundColor Green
if (-not $Beklemeden) {
  Write-Host "Bu pencereyi kapatmak icin bir tusa basin..."
  try { [void][System.Console]::ReadKey($true) } catch {}
}
