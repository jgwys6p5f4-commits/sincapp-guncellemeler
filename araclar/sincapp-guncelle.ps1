# SincApp güncelleme teşhis + onarım
# - Kurulu sürümü, güncelleme ayarını, masaüstü kısayollarını ve son güncelleme
#   kayıtlarını gösterir.
# - Kurulu sürüm eskiyse ya da güncellemeleri yanlış yerden arıyorsa en son sürümü
#   GitHub'dan indirip sessizce kurar (kısayollar ve ayarlar korunur).
# Sonuç masaüstüne "sincapp-rapor.txt" olarak kaydedilir ve panoya kopyalanır.
param([switch]$SadeceRapor, [switch]$Beklemeden)
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$r = New-Object System.Collections.Generic.List[string]
function Ekle($s) { $r.Add($s); Write-Host $s }

$REPO = 'jgwys6p5f4-commits/sincapp-guncellemeler'
$klasor = Join-Path $env:LOCALAPPDATA 'Programs\SincApp'
$exe = Join-Path $klasor 'SincApp.exe'

Ekle "=== SINCAPP GUNCELLEME KONTROLU — $(Get-Date -Format 'dd.MM.yyyy HH:mm') — $env:COMPUTERNAME ==="

# 1) Kurulu sürüm
$kurulu = $null
if (Test-Path $exe) {
  $kurulu = (Get-Item $exe).VersionInfo.ProductVersion -replace '\.0$', ''
  Ekle "Kurulu surum: $kurulu  ($exe)"
  $yml = Get-Content (Join-Path $klasor 'resources\app-update.yml') -Raw
  $repoSatir = ($yml -split "`n" | Where-Object { $_ -match '^repo:' }) -join ''
  Ekle "Guncelleme kaynagi: $($repoSatir.Trim())"
} else {
  Ekle "SincApp bu kullanicida kurulu degil ($exe yok)"
}
# Başka yerlerde kopya var mı (elle kopyalanmış/eski kurulum)
$diger = @("$env:ProgramFiles\SincApp\SincApp.exe", "${env:ProgramFiles(x86)}\SincApp\SincApp.exe") | Where-Object { Test-Path $_ }
foreach ($d in $diger) { Ekle "Baska kopya: $d  surum $((Get-Item $d).VersionInfo.ProductVersion)" }
# Uygulamanın eski adıyla ("Sigorta RDP") yapılmış kurulum: ayrı bir uygulama
# olarak duruyor ve hiç güncellenmiyor
$eskiKlasor = Join-Path $env:LOCALAPPDATA 'Programs\Sigorta RDP'
$eskiExe = Join-Path $eskiKlasor 'Sigorta RDP.exe'
$eskiVar = Test-Path $eskiExe
if ($eskiVar) { Ekle "!!! ESKI 'Sigorta RDP' uygulamasi kurulu (surum $((Get-Item $eskiExe).VersionInfo.ProductVersion)) — bu eski ad, hic guncellenmez" }

# 2) Masaüstü / Başlat kısayolları
$sh = New-Object -ComObject WScript.Shell
$yerler = @([Environment]::GetFolderPath('Desktop'), "$env:PUBLIC\Desktop", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
foreach ($y in $yerler) {
  Get-ChildItem $y -Recurse -Include *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Sinc|Sigorta' } | ForEach-Object {
    $hedef = $sh.CreateShortcut($_.FullName).TargetPath
    $not = if ($hedef -ieq $exe) { 'dogru' } elseif ($hedef -match 'Setup') { 'YANLIS: kurulum dosyasini aciyor' } else { 'FARKLI KONUM' }
    Ekle "Kisayol: $($_.FullName) -> $hedef  [$not]"
  }
}
Get-ChildItem ([Environment]::GetFolderPath('Desktop')) -Filter '*.exe' | Where-Object { $_.Name -match 'Sinc' } | ForEach-Object {
  Ekle "Masaustunde exe: $($_.Name) (surum $($_.VersionInfo.ProductVersion)) — kurulum dosyasi olabilir, uygulama degil"
}

# 3) Son güncelleme kayıtları
$log = Join-Path $env:APPDATA 'SincApp\logs\sincapp.log'
if (Test-Path $log) {
  Ekle "--- son guncelleme kayitlari ---"
  Get-Content $log -Encoding UTF8 | Select-String 'UPDATER|basladi|başladı' | Select-Object -Last 8 | ForEach-Object { Ekle "  $($_.Line)" }
} else { Ekle "Gunluk dosyasi yok (1.0.3 oncesi surumler gunluk tutmuyordu)" }

# 4) En son yayınlanan sürüm
try {
  $son = (Invoke-WebRequest "https://github.com/$REPO/releases/latest/download/latest.yml" -UseBasicParsing -TimeoutSec 30).Content
  if ($son -is [byte[]]) { $son = [Text.Encoding]::UTF8.GetString($son) }
  $sonSurum = ([regex]::Match($son, 'version:\s*(\S+)')).Groups[1].Value
  $sonDosya = ([regex]::Match($son, 'path:\s*(\S+)')).Groups[1].Value
  Ekle "Yayindaki en son surum: $sonSurum"
} catch { Ekle "!!! GitHub'a ulasilamadi: $($_.Exception.Message)"; $sonSurum = $null }

# 5) Gerekirse güncelle
$gerekli = $false
if ($sonSurum) {
  if (-not $kurulu) { $gerekli = $true }
  elseif ([version]$kurulu -lt [version]$sonSurum) { $gerekli = $true }
  elseif ($repoSatir -notmatch 'sincapp-guncellemeler') { $gerekli = $true }
}
if ($gerekli -and $SadeceRapor) {
  Ekle ""
  Ekle ">>> Guncelleme gerekli ($kurulu -> $sonSurum) — rapor modunda kurulmadi"
} elseif ($gerekli) {
  Ekle ""
  Ekle ">>> Guncelleme gerekli — $sonSurum indiriliyor (yaklasik 100 MB)..."
  $hedef = Join-Path $env:TEMP $sonDosya
  try {
    Invoke-WebRequest "https://github.com/$REPO/releases/download/v$sonSurum/$sonDosya" -OutFile $hedef -UseBasicParsing -TimeoutSec 900
    Get-Process SincApp -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    Ekle ">>> Kuruluyor..."
    $p = Start-Process $hedef -ArgumentList '/S' -PassThru -Wait
    Start-Sleep -Seconds 2
    $yeni = (Get-Item $exe).VersionInfo.ProductVersion -replace '\.0$', ''
    if ($yeni -eq $sonSurum) { Ekle ">>> TAMAM: SincApp $yeni kuruldu. Bundan sonra acilista kendiliginden guncellenecek." }
    else { Ekle "!!! Kurulumdan sonra surum $yeni gorunuyor (beklenen $sonSurum), cikis kodu $($p.ExitCode)" }
    Remove-Item $hedef -Force
  } catch { Ekle "!!! Indirme/kurulum hatasi: $($_.Exception.Message)" }
} elseif ($sonSurum) {
  Ekle ""
  Ekle "SincApp guncel ($kurulu). Otomatik guncelleme ayari dogru."
}

# 6) Eski "Sigorta RDP" uygulamasını kaldır (yeni SincApp kuruluysa)
if ($eskiVar -and -not $SadeceRapor -and (Test-Path $exe)) {
  Ekle ""
  Ekle ">>> Eski 'Sigorta RDP' uygulamasi kaldiriliyor..."
  Get-Process 'Sigorta RDP' -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 1
  $kaldir = Get-ChildItem $eskiKlasor -Filter 'Uninstall*.exe' | Select-Object -First 1
  if ($kaldir) { Start-Process $kaldir.FullName -ArgumentList '/S' -Wait; Start-Sleep -Seconds 2 }
  # Kalan kısayolları temizle
  foreach ($y in $yerler) {
    Get-ChildItem $y -Recurse -Include *.lnk -ErrorAction SilentlyContinue | Where-Object {
      $sh.CreateShortcut($_.FullName).TargetPath -ieq $eskiExe
    } | Remove-Item -Force
  }
  if (Test-Path $eskiExe) { Ekle "!!! Eski uygulama tam kaldirilamadi: $eskiKlasor" } else { Ekle ">>> Eski 'Sigorta RDP' kaldirildi. Masaustundeki 'SincApp' kisayolunu kullanin." }
} elseif ($eskiVar -and $SadeceRapor) {
  Ekle ">>> Eski 'Sigorta RDP' kaldirilmali — rapor modunda dokunulmadi"
}

$rapor = Join-Path ([Environment]::GetFolderPath('Desktop')) 'sincapp-rapor.txt'
$r | Out-File $rapor -Encoding UTF8
$r -join "`r`n" | Set-Clipboard
Write-Host ""
Write-Host "Rapor masaustune kaydedildi ve panoya kopyalandi: $rapor" -ForegroundColor Green
if (-not $Beklemeden) {
  Write-Host "Kapatmak icin bir tusa basin..."
  try { [void][System.Console]::ReadKey($true) } catch {}
}
