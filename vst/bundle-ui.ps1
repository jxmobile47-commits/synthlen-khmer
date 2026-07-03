# =============================================================================
# bundle-ui.ps1
# Copies the Synthlen Khmer web UI (HTML + uploaded images) into vst/ui/ and
# generates manifest.json, so the assets can be embedded into the VST plugin
# via JUCE binary data. Run this BEFORE configuring/building with CMake.
#
#   powershell -ExecutionPolicy Bypass -File .\bundle-ui.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

$root     = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\vst
$project  = Split-Path -Parent $root                          # ...\UI UX Desing
$uiDir    = Join-Path $root "ui"
$uploads  = Join-Path $project "uploads"
$html     = Join-Path $project "synthlen-khmer.html"

# Fresh ui/ folder
if (Test-Path $uiDir) { Remove-Item $uiDir -Recurse -Force }
New-Item -ItemType Directory -Path $uiDir | Out-Null

# 1) Copy the main HTML document
Copy-Item $html (Join-Path $uiDir "synthlen-khmer.html") -Force

# 2) Copy every image (flattened - the resource provider matches by file name)
$instruments = @{}
$background   = $null
$slideshow    = @()

function Copy-Img($file) {
    Copy-Item $file.FullName (Join-Path $uiDir $file.Name) -Force
}

# Instruments
$instDir = Join-Path $uploads "instruments"
if (Test-Path $instDir) {
    Get-ChildItem $instDir -File | ForEach-Object {
        Copy-Img $_
        $name = $_.BaseName    # roneat / chayam / tror / pin
        $instruments[$name] = "/uploads/instruments/$($_.Name)"
    }
}

# Background
$bgDir = Join-Path $uploads "background"
if (Test-Path $bgDir) {
    $bg = Get-ChildItem $bgDir -File | Select-Object -First 1
    if ($bg) {
        Copy-Img $bg
        $background = "/uploads/background/$($bg.Name)"
    }
}

# Slideshow
$slideDir = Join-Path $uploads "slideshow"
if (Test-Path $slideDir) {
    Get-ChildItem $slideDir -File | Sort-Object Name | ForEach-Object {
        Copy-Img $_
        $slideshow += "/uploads/slideshow/$($_.Name)"
    }
}

# 3) Write manifest.json (same shape the HTML expects from /api/manifest)
$manifest = [ordered]@{
    instruments = $instruments
    background  = $background
    slideshow   = $slideshow
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $uiDir "manifest.json") -Encoding UTF8

Write-Host "Bundled UI into $uiDir"
Write-Host ("  instruments : " + ($instruments.Keys -join ", "))
Write-Host ("  background  : " + $background)
Write-Host ("  slideshow   : " + $slideshow.Count + " image(s)")
