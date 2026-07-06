# Synthlen Khmer - Build Single-File EXE Installer
# Creates ONE real .exe (C# launcher) with ZIP payload appended.
# Uses streaming to avoid OutOfMemory with large files (2GB+).
#
# Usage: powershell -ExecutionPolicy Bypass -File build-exe-installer.ps1

$ErrorActionPreference = "Stop"
$installerDir = $PSScriptRoot
$projectRoot = Split-Path $installerDir -Parent
$buildDir = Join-Path $projectRoot "build\SynthlenKhmer_artefacts\Release"
$outputDir = Join-Path $installerDir "output"
$version = "1.0.0"
$pkgName = "SynthlenKhmer-Setup-$version"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Single-File EXE Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Launcher.exe exists
$launcherExe = Join-Path $installerDir "Launcher.exe"
if (-not (Test-Path $launcherExe)) {
    Write-Host "ERROR: Launcher.exe not found. Build it first:" -ForegroundColor Red
    Write-Host "  csc Launcher.cs /out:Launcher.exe /target:exe /platform:anycpu /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll" -ForegroundColor Yellow
    exit 1
}

# Clean output
$pkgDir = Join-Path $outputDir $pkgName
if (Test-Path $pkgDir) { Remove-Item $pkgDir -Recurse -Force }
New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
$payloadDir = Join-Path $pkgDir "payload"
New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null

# 1. VST3
$vst3Source = Join-Path $buildDir "VST3\Synthlen Khmer.vst3"
if (Test-Path $vst3Source) {
    Write-Host "[1/3] Staging VST3 plugin..." -ForegroundColor Yellow
    Copy-Item $vst3Source $payloadDir -Recurse -Force
    Write-Host "  -> OK" -ForegroundColor Green
} else {
    Write-Host "[1/3] VST3 not found - skipping" -ForegroundColor Red
}

# 2. Standalone
$standaloneSource = Join-Path $buildDir "Standalone"
if (Test-Path $standaloneSource) {
    Write-Host "[2/3] Staging Standalone app..." -ForegroundColor Yellow
    $dest = Join-Path $payloadDir "Standalone"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item "$standaloneSource\Synthlen Khmer.exe" $dest -Force
    Write-Host "  -> OK" -ForegroundColor Green
} else {
    Write-Host "[2/3] Standalone not found - skipping" -ForegroundColor Red
}

# 3. Encrypted bank pack
$banksPack = Join-Path $projectRoot "SynthlenKhmer.banks"
if (Test-Path $banksPack) {
    Write-Host "[3/3] Staging encrypted bank pack..." -ForegroundColor Yellow
    Copy-Item $banksPack (Join-Path $payloadDir "Standalone") -Force
    $sizeMB = "{0:N1}" -f ((Get-Item $banksPack).Length / 1MB)
    Write-Host "  -> OK ($sizeMB MB, encrypted)" -ForegroundColor Green
} else {
    Write-Host "[3/3] SynthlenKhmer.banks not found - run pack-banks.ps1 first!" -ForegroundColor Red
}

# ===== Create installer.bat =====
$batContent = @'
@echo off
title Synthlen Khmer Installer v1.0.0
color 0A
echo.
echo  ========================================
echo    Synthlen Khmer Installer v1.0.0
echo  ========================================
echo.

set "PAYLOAD=%~dp0payload"
set "VST3DEST=C:\Program Files\Common Files\VST3"
set "APPDEST=C:\Program Files\Synthlen Khmer"
set "BANKSDEST=%USERPROFILE%\Documents\Synthlen Khmer"

echo  [1/3] Installing VST3 plugin...
if exist "%PAYLOAD%\Synthlen Khmer.vst3" (
    if not exist "%VST3DEST%" mkdir "%VST3DEST%"
    xcopy "%PAYLOAD%\Synthlen Khmer.vst3" "%VST3DEST%\Synthlen Khmer.vst3\" /E /I /Y /Q >nul
    echo  -^> Installed to %VST3DEST%
) else (
    echo  -^> VST3 not found, skipping
)

echo.
echo  [2/3] Installing Standalone application...
if exist "%PAYLOAD%\Standalone\Synthlen Khmer.exe" (
    if not exist "%APPDEST%" mkdir "%APPDEST%"
    copy "%PAYLOAD%\Standalone\Synthlen Khmer.exe" "%APPDEST%\" /Y >nul
    powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Synthlen Khmer.lnk');$s.TargetPath='%APPDEST%\Synthlen Khmer.exe';$s.Save()"
    powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Synthlen Khmer.lnk');$s.TargetPath='%APPDEST%\Synthlen Khmer.exe';$s.Save()"
    echo  -^> Installed to %APPDEST%
    echo  -^> Created Start Menu + Desktop shortcuts
) else (
    echo  -^> Standalone not found, skipping
)

echo.
echo  [3/3] Installing sound banks (2.4 GB, please wait)...
set "VST3BANK=%VST3DEST%\Synthlen Khmer.vst3\Contents\Resources\SynthlenKhmer.banks"
if exist "%VST3BANK%" (
    set "SHAREDDIR=%ProgramData%\Synthlen Khmer"
    if not exist "%SHAREDDIR%" mkdir "%SHAREDDIR%"
    copy "%VST3BANK%" "%SHAREDDIR%\" /Y >nul
    if not exist "%BANKSDEST%" mkdir "%BANKSDEST%"
    copy "%VST3BANK%" "%BANKSDEST%\" /Y >nul
    copy "%VST3BANK%" "%APPDEST%\" /Y >nul
    echo  -^> Copied banks from VST3 to ProgramData, Documents, and app folder
) else (
    echo  -^> Sound banks not found in VST3, skipping
)

echo.
echo  ========================================
echo    Installation Complete!
echo  ========================================
echo.
echo  VST3:       %VST3DEST%
echo  Standalone: %APPDEST%
echo  Presets:    Encrypted bank pack installed
echo.
set /p LAUNCH="Launch Synthlen Khmer now? (y/n): "
if /i "%LAUNCH%"=="y" (
    start "" "%APPDEST%\Synthlen Khmer.exe"
)
exit /b
'@

$batPath = Join-Path $pkgDir "Install-SynthlenKhmer.bat"
$batContent | Out-File -FilePath $batPath -Encoding ASCII

# ===== Create ZIP =====
$zipPath = Join-Path $env:TEMP "sk_payload.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host ""
Write-Host "  Creating ZIP..." -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($pkgDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
$zipSize = (Get-Item $zipPath).Length
Write-Host "  -> ZIP: $([math]::Round($zipSize/1MB, 1)) MB" -ForegroundColor Green

# ===== Build single EXE: Launcher.exe + marker + ZIP =====
Write-Host ""
Write-Host "  Building single-file EXE..." -ForegroundColor Yellow

$exePath = Join-Path $outputDir "$pkgName.exe"
if (Test-Path $exePath) { Remove-Item $exePath -Force }

# Stream: Launcher.exe -> marker "SKZIP1\0\0" (8 bytes) -> ZIP data
$marker = [byte[]]@(0x53,0x4B,0x5A,0x49,0x50,0x31,0x00,0x00)

$outStream = [System.IO.File]::Create($exePath)
# 1. Write Launcher.exe
$launcherBytes = [System.IO.File]::ReadAllBytes($launcherExe)
$outStream.Write($launcherBytes, 0, $launcherBytes.Length)
# 2. Write marker
$outStream.Write($marker, 0, $marker.Length)
# 3. Stream ZIP data (1MB chunks - no memory issue)
$zipStream = [System.IO.File]::OpenRead($zipPath)
$zipStream.CopyTo($outStream, 1048576)
$zipStream.Close()
$outStream.Close()

# Cleanup
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue

$finalSize = (Get-Item $exePath).Length / 1MB

Write-Host ""
Write-Host "  ======================================== " -ForegroundColor Green
Write-Host "  Single-File EXE Installer Created!" -ForegroundColor Green
Write-Host "  ======================================== " -ForegroundColor Green
Write-Host ""
Write-Host "  EXE:  $exePath" -ForegroundColor White
Write-Host "  Size: $([math]::Round($finalSize, 1)) MB" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To install: Double-click the .exe (UAC will prompt for admin)" -ForegroundColor Cyan
Write-Host ""
