# SincApp tam kontrol: ekran teşhisi + güncelleme onarımı (tek komutla).
# Araçları herkese açık güncelleme reposundan indirir, sırayla çalıştırır ve
# iki raporu birleştirip panoya kopyalar (masaüstüne de "sincapp-tam-rapor.txt").
# Çalıştırma (Win+R'ye yapıştır):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/jgwys6p5f4-commits/sincapp-guncellemeler/main/araclar/kontrol.ps1 -OutFile $env:TEMP\sk.ps1; & $env:TEMP\sk.ps1"
param([switch]$SadeceRapor)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$taban = 'https://raw.githubusercontent.com/jgwys6p5f4-commits/sincapp-guncellemeler/main/araclar'
$masaustu = [Environment]::GetFolderPath('Desktop')

Write-Host "SincApp kontrol araclari indiriliyor..." -ForegroundColor Cyan
foreach ($ad in 'ekran-teshis.ps1', 'sincapp-guncelle.ps1') {
  Invoke-WebRequest "$taban/$ad" -OutFile (Join-Path $env:TEMP $ad) -UseBasicParsing -TimeoutSec 60
}

Write-Host "`n===== 1/2 EKRAN =====`n" -ForegroundColor Cyan
& (Join-Path $env:TEMP 'ekran-teshis.ps1') -Beklemeden
Write-Host "`n===== 2/2 SINCAPP GUNCELLEME =====`n" -ForegroundColor Cyan
if ($SadeceRapor) { & (Join-Path $env:TEMP 'sincapp-guncelle.ps1') -Beklemeden -SadeceRapor }
else { & (Join-Path $env:TEMP 'sincapp-guncelle.ps1') -Beklemeden }

$parcalar = 'ekran-raporu.txt', 'sincapp-rapor.txt' | ForEach-Object { Join-Path $masaustu $_ } | Where-Object { Test-Path $_ }
$tam = ($parcalar | ForEach-Object { Get-Content $_ -Raw -Encoding UTF8 }) -join "`r`n`r`n"
$tamYol = Join-Path $masaustu 'sincapp-tam-rapor.txt'
$tam | Out-File $tamYol -Encoding UTF8
$tam | Set-Clipboard
$parcalar | Remove-Item -Force

Write-Host "`nTAMAMLANDI. Rapor panoya kopyalandi ve masaustune kaydedildi: $tamYol" -ForegroundColor Green
Write-Host "Raporu Claude'a yapistirin (Ctrl+V). Kapatmak icin bir tusa basin..."
try { [void][System.Console]::ReadKey($true) } catch {}
