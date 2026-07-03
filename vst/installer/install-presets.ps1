# Synthlen Khmer - Preset Pack Installer (PowerShell fallback)
# Run: powershell -ExecutionPolicy Bypass -File install-presets.ps1
# Copies preset folders from .\preset-source\ into the plugin's banks directory.

param(
    [string]$PresetSource = ".\preset-source",
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$banksDest = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Synthlen Khmer", "banks")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Synthlen Khmer - Preset Pack Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $PresetSource)) {
    Write-Host "Error: Preset source folder not found: $PresetSource" -ForegroundColor Red
    Write-Host "Please create a 'preset-source' folder and copy the preset folders into it." -ForegroundColor Yellow
    exit 1
}

$presets = Get-ChildItem $PresetSource -Directory
if ($presets.Count -eq 0) {
    Write-Host "Error: No preset folders found in $PresetSource" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($presets.Count) preset(s) to install:" -ForegroundColor Yellow
$presets | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
Write-Host ""

if (-not (Test-Path $banksDest)) {
    New-Item -ItemType Directory -Path $banksDest -Force | Out-Null
    Write-Host "Created banks directory: $banksDest" -ForegroundColor Green
}

foreach ($preset in $presets) {
    $destPath = Join-Path $banksDest $preset.Name
    Write-Host "Installing: $($preset.Name)..." -ForegroundColor Yellow -NoNewline
    Copy-Item $preset.FullName $destPath -Recurse -Force
    Write-Host " Done" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Preset Pack Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installed to: $banksDest" -ForegroundColor White
Write-Host ""
