# Synthlen Khmer - Installer Guide

## Quick Start

### Option A: Inno Setup (recommended for selling)
1. Download & install **Inno Setup 6** (free): https://jrsoftware.org/isdl.php
2. Run `build-installer.ps1` to build plugin + compile installers
3. Find `.exe` installers in `.\output\`

### Option B: PowerShell (no Inno Setup needed)
1. Build the plugin first: `cmake --build build --config Release`
2. Run `install-full.ps1` on the target machine

---

## Files

| File | Description |
|------|-------------|
| `full-installer.iss` | Inno Setup script: installs VST3 + Standalone + all presets |
| `preset-pack.iss` | Inno Setup script: installs preset sound banks only |
| `install-full.ps1` | PowerShell fallback: full installation |
| `install-presets.ps1` | PowerShell fallback: preset pack installation |
| `build-installer.ps1` | Master build script: builds plugin + compiles installers |

---

## Selling Preset Packs

To create a separate preset pack installer:

1. Create a folder: `installer\preset-source\`
2. Copy the preset folders you want to include (e.g. `Khim`, `Sralai Ek`, etc.)
3. Build with Inno Setup: `ISCC.exe preset-pack.iss`
4. The installer copies presets to `Documents\Synthlen Khmer\banks\`

Example: Create a "Khmer Strings Pack" with just `Sralai`, `Sralai Ek`, `Sralai Thom`, `Sralai Toch`.

---

## What Gets Installed

### Full Installer
- **VST3**: `C:\Program Files\Common Files\VST3\Synthlen Khmer.vst3`
- **Standalone**: `C:\Program Files\Synthlen Khmer\Synthlen Khmer.exe`
- **Presets**: `Documents\Synthlen Khmer\banks\` (45 instruments, ~2.4 GB)
- **Start Menu** shortcut for Standalone

### Preset Pack Installer
- **Presets only**: `Documents\Synthlen Khmer\banks\` (adds new folders)

---

## Notes

- The plugin loads presets from `Documents\Synthlen Khmer\banks\` automatically
- Presets are discovered by folder name at startup
- No license/copy protection is included yet - consider adding for commercial release
- For large preset packs (>1GB), Inno Setup supports disk spanning (split into multiple files)
