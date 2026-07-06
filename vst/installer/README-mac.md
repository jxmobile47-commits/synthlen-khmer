# Synthlen Khmer - macOS Build & Install Guide

## តម្រូវការ / Prerequisites

- macOS 10.15+ (Catalina or newer)
- Xcode Command Line Tools: `xcode-select --install`
- CMake 3.22+: `brew install cmake`
- The `SynthlenKhmer.banks` file (encrypted bank pack, 2.4 GB)

## របៀប Build / Build Steps

### 1. Build the plugin
```bash
cd vst
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

Build artifacts will be in:
```
vst/build/SynthlenKhmer_artefacts/Release/
├── VST3/Synthlen Khmer.vst3
└── Standalone/Synthlen Khmer.app
```

### 2. Build the installer
```bash
cd vst/installer
chmod +x build-mac-installer.sh
./build-mac-installer.sh
```

This creates:
- `output/SynthlenKhmer-Setup-1.0.0.pkg` — macOS installer package
- `output/SynthlenKhmer-Setup-1.0.0.dmg` — disk image (if hdiutil available)

### 3. Install
- Double-click the `.pkg` file
- Follow the installer wizard
- Enter administrator password when prompted

Installer installs:
- **Standalone app** → `/Applications/Synthlen Khmer.app` (with bank bundled inside)
- **VST3 plugin** → `/Library/Audio/Plug-Ins/VST3/Synthlen Khmer.vst3`
- **Bank pack** → `~/Documents/Synthlen Khmer/SynthlenKhmer.banks` (fallback)

## ចែកចាយ / Distribution

1. Upload `SynthlenKhmer-Setup-1.0.0.pkg` or `.dmg` to Google Drive
2. Share the link with users
3. Users download and install — **one time only, no separate bank download needed**

## ចំណាំ / Notes

- The bank pack is encrypted (XOR) — users cannot extract raw samples
- The standalone app has the bank bundled inside the `.app` package
- VST3 plugin reads the bank from `~/Documents/Synthlen Khmer/` or next to the plugin
- For code signing: `codesign --deep --sign "Developer ID Application: YOUR_NAME" "Synthlen Khmer.app"`
- For notarization: `xcrun notarytool submit "SynthlenKhmer-Setup-1.0.0.pkg" --apple-id YOUR_ID --team-id TEAM_ID --wait`
