# Synthlen Khmer - Build Installer Script
# Run: powershell -ExecutionPolicy Bypass -File build-installer.ps1
# This script builds the plugin, then compiles installers with Inno Setup (if available).

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$cmake = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Synthlen Khmer - Build Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Bundle UI
Write-Host "`n[1/4] Bundling UI..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File "$projectRoot\bundle-ui.ps1" | Out-Null
Write-Host "  Done" -ForegroundColor Green

# Step 2: Reconfigure CMake (picks up new UI files)
Write-Host "`n[2/4] Reconfiguring CMake..." -ForegroundColor Yellow
& $cmake -B "$projectRoot\build" -S $projectRoot -G "Visual Studio 17 2022" -A x64 2>&1 | Select-Object -Last 3
Write-Host "  Done" -ForegroundColor Green

# Step 3: Build Release
Write-Host "`n[3/4] Building plugin (Release)..." -ForegroundColor Yellow
& $cmake --build "$projectRoot\build" --config Release 2>&1 | Select-Object -Last 5
if ($LASTEXITCODE -ne 0) { Write-Host "Build FAILED" -ForegroundColor Red; exit 1 }
Write-Host "  Done" -ForegroundColor Green

# Step 4: Compile installers with Inno Setup
Write-Host "`n[4/4] Building installers..." -ForegroundColor Yellow
$iscc = $null
$innoPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
foreach ($p in $innoPaths) {
    if (Test-Path $p) { $iscc = $p; break }
}

if ($iscc) {
    Write-Host "  Inno Setup found: $iscc" -ForegroundColor Green
    
    # Full installer
    Write-Host "  Building full installer..." -ForegroundColor Yellow
    & $iscc "$scriptDir\full-installer.iss" 2>&1 | Select-Object -Last 3
    Write-Host "  Full installer: $scriptDir\output\" -ForegroundColor Green
    
    # Preset pack installer (only if preset-source exists)
    if (Test-Path "$scriptDir\preset-source") {
        Write-Host "  Building preset pack installer..." -ForegroundColor Yellow
        & $iscc "$scriptDir\preset-pack.iss" 2>&1 | Select-Object -Last 3
        Write-Host "  Preset pack: $scriptDir\output\" -ForegroundColor Green
    } else {
        Write-Host "  Skipping preset pack (no preset-source folder)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Inno Setup not installed - using PowerShell fallback" -ForegroundColor Yellow
    Write-Host "  Run install-full.ps1 on the target machine instead" -ForegroundColor White
    Write-Host "  Download Inno Setup (free): https://jrsoftware.org/isdl.php" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Plugin output:" -ForegroundColor White
Write-Host "  VST3:       $projectRoot\build\SynthlenKhmer_artefacts\Release\VST3\" -ForegroundColor White
Write-Host "  Standalone: $projectRoot\build\SynthlenKhmer_artefacts\Release\Standalone\" -ForegroundColor White
if (Test-Path "$scriptDir\output") {
    Write-Host "Installers:  $scriptDir\output\" -ForegroundColor White
}
Write-Host ""
