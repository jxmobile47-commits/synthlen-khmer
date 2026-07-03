# =============================================================================
# bundle-banks.ps1
# Flattens sound-bank samples for embedding into the plugin.
#
#   banks/<Preset Name>/<sample>.wav
#       -> banks_flat/<PresetNoSpaces>__<sample>.wav
#
# The C++ side (loadBankSamples) matches files by the "<PresetNoSpaces>__"
# prefix. Run this whenever you add/change samples, then re-configure CMake.
#
#   powershell -ExecutionPolicy Bypass -File .\bundle-banks.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\vst
$banks   = Join-Path $root "banks"
$flat    = Join-Path $root "banks_flat"

# Fresh banks_flat/
if (Test-Path $flat) { Remove-Item $flat -Recurse -Force }
New-Item -ItemType Directory -Path $flat | Out-Null

if (-not (Test-Path $banks) -or (Get-ChildItem $banks -Directory -ErrorAction SilentlyContinue).Count -eq 0) {
    # Try Documents\Synthlen Khmer\banks as fallback source
    $docBanks = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Synthlen Khmer\banks"
    if (Test-Path $docBanks) {
        Write-Host "Copying banks from Documents to vst\banks..."
        New-Item -ItemType Directory -Path $banks -Force | Out-Null
        Copy-Item "$docBanks\*" $banks -Recurse -Force
    } else {
        Write-Host "No banks/ folder found - nothing to embed."
        exit 0
    }
}

$total = 0
Get-ChildItem $banks -Directory | ForEach-Object {
    $preset = $_.Name
    $prefix = ($preset -replace '\s', '')   # strip spaces -> matches C++
    $count = 0
    Get-ChildItem $_.FullName -File -Include *.wav,*.aif,*.aiff,*.flac -Recurse | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $flat "${prefix}__$($_.Name)") -Force
        $count++; $total++
    }
    Write-Host ("  {0,-16} -> {1} sample(s)" -f $preset, $count)
}

Write-Host "Flattened $total sample(s) into banks_flat/"
if ($total -eq 0) {
    Write-Host "(Drop .wav files into banks/<Preset>/ then re-run, e.g. banks/Angkor Sunset/roneat_C3.wav)"
}
