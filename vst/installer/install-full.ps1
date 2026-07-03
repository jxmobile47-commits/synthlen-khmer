# Synthlen Khmer - Full Installer (PowerShell fallback)
# Run: powershell -ExecutionPolicy Bypass -File install-full.ps1
# Use this if Inno Setup is not installed.

param(
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$pluginName = "Synthlen Khmer"
$vst3Source = "..\build\SynthlenKhmer_artefacts\Release\VST3\Synthlen Khmer.vst3"
$standaloneSource = "..\build\SynthlenKhmer_artefacts\Release\Standalone"
$banksSource = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Synthlen Khmer", "banks")
$vst3Dest = [System.IO.Path]::Combine($env:CommonProgramFiles, "VST3")
$appDest = [System.IO.Path]::Combine($env:ProgramFiles, $pluginName)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Synthlen Khmer - Full Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Install VST3
Write-Host "[1/3] Installing VST3 plugin..." -ForegroundColor Yellow
if (Test-Path $vst3Source) {
    if (-not (Test-Path $vst3Dest)) { New-Item -ItemType Directory -Path $vst3Dest -Force | Out-Null }
    Copy-Item $vst3Source $vst3Dest -Recurse -Force
    Write-Host "  -> Copied to $vst3Dest" -ForegroundColor Green
} else {
    Write-Host "  -> VST3 not found at $vst3Source - skipping" -ForegroundColor Red
}

# 2. Install Standalone
Write-Host "[2/3] Installing Standalone application..." -ForegroundColor Yellow
if (Test-Path $standaloneSource) {
    if (-not (Test-Path $appDest)) { New-Item -ItemType Directory -Path $appDest -Force | Out-Null }
    Copy-Item "$standaloneSource\Synthlen Khmer.exe" $appDest -Force
    $webview2Dir = "$standaloneSource\Synthlen Khmer.exe.WebView2"
    if (Test-Path $webview2Dir) {
        Copy-Item $webview2Dir "$appDest\Synthlen Khmer.exe.WebView2" -Recurse -Force
    }
    Write-Host "  -> Copied to $appDest" -ForegroundColor Green
    
    # Create Start Menu shortcut
    $shortcutPath = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs", "$pluginName.lnk")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$appDest\Synthlen Khmer.exe"
    $shortcut.Save()
    Write-Host "  -> Created Start Menu shortcut" -ForegroundColor Green
} else {
    Write-Host "  -> Standalone not found - skipping" -ForegroundColor Red
}

# 3. Install Preset Banks
Write-Host "[3/3] Installing preset sound banks..." -ForegroundColor Yellow
if (Test-Path $banksSource) {
    $destBanks = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Synthlen Khmer", "banks")
    if (-not (Test-Path $destBanks)) { New-Item -ItemType Directory -Path $destBanks -Force | Out-Null }
    
    $presetCount = (Get-ChildItem $banksSource -Directory).Count
    Write-Host "  -> Copying $presetCount presets..." -ForegroundColor Yellow
    Copy-Item "$banksSource\*" $destBanks -Recurse -Force
    Write-Host "  -> Copied to $destBanks" -ForegroundColor Green
} else {
    Write-Host "  -> Banks not found at $banksSource - skipping" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "VST3:      $vst3Dest" -ForegroundColor White
Write-Host "Standalone: $appDest" -ForegroundColor White
Write-Host "Presets:    $([System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'Synthlen Khmer', 'banks'))" -ForegroundColor White
Write-Host ""

if (-not $Silent) {
    $launch = Read-Host "Launch Synthlen Khmer now? (y/n)"
    if ($launch -eq "y" -or $launch -eq "Y") {
        Start-Process "$appDest\Synthlen Khmer.exe"
    }
}
