#!/bin/bash
# Synthlen Khmer - macOS Installer Builder
# Creates a .pkg installer that bundles VST3 + Standalone + SynthlenKhmer.banks
#
# Usage: chmod +x build-mac-installer.sh && ./build-mac-installer.sh
# Run on macOS after building the plugin with CMake.
#
# Prerequisites:
#   - CMake build completed: vst/build/SynthlenKhmer_artefacts/Release/
#   - SynthlenKhmer.banks in vst/ (encrypted bank pack)
#   - macOS with pkgbuild & productbuild (built-in)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/SynthlenKhmer_artefacts/Release"
VERSION="1.0.0"
OUTPUT_DIR="$SCRIPT_DIR/output"
PKG_NAME="SynthlenKhmer-Setup-$VERSION.pkg"

echo ""
echo "========================================"
echo "  Building macOS .pkg Installer"
echo "========================================"
echo ""

# Check build artifacts
VST3_SOURCE="$BUILD_DIR/VST3/Synthlen Khmer.vst3"
STANDALONE_SOURCE="$BUILD_DIR/Standalone/Synthlen Khmer.app"
BANKS_PACK="$PROJECT_ROOT/SynthlenKhmer.banks"

if [ ! -d "$VST3_SOURCE" ]; then
    echo "ERROR: VST3 not found at $VST3_SOURCE"
    echo "Build the plugin first: cmake --build build --config Release"
    exit 1
fi

if [ ! -d "$STANDALONE_SOURCE" ]; then
    echo "ERROR: Standalone app not found at $STANDALONE_SOURCE"
    echo "Build the plugin first: cmake --build build --config Release"
    exit 1
fi

if [ ! -f "$BANKS_PACK" ]; then
    echo "ERROR: SynthlenKhmer.banks not found at $BANKS_PACK"
    echo "Run pack-banks.ps1 or place the encrypted bank pack in vst/"
    exit 1
fi

BANKS_SIZE=$(du -h "$BANKS_PACK" | cut -f1)
echo "Bank pack size: $BANKS_SIZE"
echo ""

# Create staging directory
STAGING_DIR="$OUTPUT_DIR/staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# ---- Component 1: VST3 plugin ----
echo "[1/3] Staging VST3 plugin..."
VST3_DEST="$STAGING_DIR/vst3"
mkdir -p "$VST3_DEST"
cp -R "$VST3_SOURCE" "$VST3_DEST/"
echo "  -> OK"

# ---- Component 2: Standalone app + bank ----
echo "[2/3] Staging Standalone app + bank pack..."
APP_DEST="$STAGING_DIR/app"
mkdir -p "$APP_DEST"
cp -R "$STANDALONE_SOURCE" "$APP_DEST/"

# Copy SynthlenKhmer.banks into the .app bundle (next to executable)
APP_CONTENTS="$APP_DEST/Synthlen Khmer.app/Contents"
# Place bank in Contents/Resources/ and also next to MacOS/ for fallback
cp "$BANKS_PACK" "$APP_CONTENTS/Resources/"
# Also place in the same dir as the executable for findPackFile() to find it
cp "$BANKS_PACK" "$APP_CONTENTS/MacOS/"

BANKS_SIZE_COPIED=$(du -h "$APP_CONTENTS/Resources/SynthlenKhmer.banks" | cut -f1)
echo "  -> OK (bank: $BANKS_SIZE_COPIED)"

# ---- Component 3: Bank pack to Documents (fallback) ----
echo "[3/3] Staging bank pack for Documents..."
DOCS_DEST="$STAGING_DIR/docs"
mkdir -p "$DOCS_DEST/Synthlen Khmer"
cp "$BANKS_PACK" "$DOCS_DEST/Synthlen Khmer/"
echo "  -> OK"

echo ""
echo "Building component packages..."

mkdir -p "$OUTPUT_DIR"

# Build VST3 component package
# VST3 installs to /Library/Audio/Plug-Ins/VST3/
pkgbuild \
    --root "$STAGING_DIR/vst3" \
    --identifier "com.synthlenkhmer.vst3" \
    --version "$VERSION" \
    --install-location "/Library/Audio/Plug-Ins/VST3" \
    "$OUTPUT_DIR/component-vst3.pkg"

# Build Standalone app component package
# App installs to /Applications/
pkgbuild \
    --root "$STAGING_DIR/app" \
    --identifier "com.synthlenkhmer.app" \
    --version "$VERSION" \
    --install-location "/Applications" \
    "$OUTPUT_DIR/component-app.pkg"

# Build Documents bank pack component package
# Bank installs to ~/Documents/Synthlen Khmer/
pkgbuild \
    --root "$STAGING_DIR/docs" \
    --identifier "com.synthlenkhmer.banks" \
    --version "$VERSION" \
    --install-location "$HOME/Documents" \
    "$OUTPUTDIR/component-banks.pkg"

echo ""
echo "Building final distribution .pkg..."

# Create distribution.xml for combined installer
DIST_XML="$OUTPUT_DIR/distribution.xml"
cat > "$DIST_XML" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Synthlen Khmer $VERSION</title>
    <organization>com.synthlenkhmer</organization>
    <options customize="never" require-scripts="false" rootVolumeOnly="false"/>
    <license file="license.txt"/>
    <welcome file="welcome.txt"/>
    <conclusion file="conclusion.txt"/>

    <choices-outline>
        <line choice="choice_app"/>
        <line choice="choice_vst3"/>
        <line choice="choice_banks"/>
    </choices-outline>

    <choice id="choice_app" title="Standalone Application" description="Synthlen Khmer standalone app with built-in sound banks">
        <pkg-ref id="com.synthlenkhmer.app"/>
    </choice>

    <choice id="choice_vst3" title="VST3 Plugin" description="VST3 plugin for use in DAWs (Ableton, Logic, etc.)">
        <pkg-ref id="com.synthlenkhmer.vst3"/>
    </choice>

    <choice id="choice_banks" title="Sound Banks (Documents)" description="Place encrypted bank pack in Documents folder (optional fallback)">
        <pkg-ref id="com.synthlenkhmer.banks"/>
    </choice>

    <pkg-ref id="com.synthlenkhmer.app" version="$VERSION" onConclusion="none">component-app.pkg</pkg-ref>
    <pkg-ref id="com.synthlenkhmer.vst3" version="$VERSION" onConclusion="none">component-vst3.pkg</pkg-ref>
    <pkg-ref id="com.synthlenkhmer.banks" version="$VERSION" onConclusion="none">component-banks.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create license.txt
cat > "$OUTPUT_DIR/license.txt" << EOF
Synthlen Khmer - Software License Agreement

Copyright (c) 2026 Synthlen Khmer. All rights reserved.

By installing this software you agree to use it in accordance with
the license terms provided with your purchase.

Unauthorized distribution or reverse engineering of the sound banks
is strictly prohibited.
EOF

# Create welcome.txt
cat > "$OUTPUT_DIR/welcome.txt" << EOF
Welcome to Synthlen Khmer v$VERSION

The complete Khmer instrument sample library plugin.

This installer includes:
  - Standalone Application (with built-in sound banks)
  - VST3 Plugin (for DAWs)
  - Encrypted Sound Banks (2.4 GB)

Click Continue to install.
EOF

# Create conclusion.txt
cat > "$OUTPUT_DIR/conclusion.txt" << EOF
Installation Complete!

Synthlen Khmer has been installed:

  Standalone: /Applications/Synthlen Khmer.app
  VST3:       /Library/Audio/Plug-Ins/VST3/Synthlen Khmer.vst3
  Banks:      ~/Documents/Synthlen Khmer/SynthlenKhmer.banks

You can now launch Synthlen Khmer from your Applications folder.

Created by CHHAY BORITH (DJ Yahoo)
EOF

# Build final distribution package
productbuild \
    --distribution "$DIST_XML" \
    --package-path "$OUTPUT_DIR" \
    "$OUTPUT_DIR/$PKG_NAME"

# Cleanup intermediate files
rm -f "$OUTPUT_DIR/component-vst3.pkg"
rm -f "$OUTPUT_DIR/component-app.pkg"
rm -f "$OUTPUT_DIR/component-banks.pkg"
rm -f "$OUTPUT_DIR/distribution.xml"
rm -f "$OUTPUT_DIR/license.txt"
rm -f "$OUTPUT_DIR/welcome.txt"
rm -f "$OUTPUT_DIR/conclusion.txt"
rm -rf "$STAGING_DIR"

FINAL_SIZE=$(du -h "$OUTPUT_DIR/$PKG_NAME" | cut -f1)

echo ""
echo "========================================"
echo "  macOS Installer Created!"
echo "========================================"
echo ""
echo "  PKG:  $OUTPUT_DIR/$PKG_NAME"
echo "  Size: $FINAL_SIZE"
echo ""
echo "  To install: Double-click the .pkg file"
echo "  (administrator password will be required)"
echo ""

# Optional: create DMG
if command -v hdiutil &> /dev/null; then
    echo "Creating DMG..."
    DMG_NAME="SynthlenKhmer-Setup-$VERSION.dmg"
    hdiutil create -volname "Synthlen Khmer Installer" \
        -srcfolder "$OUTPUT_DIR/$PKG_NAME" \
        -ov -format UDZO \
        "$OUTPUT_DIR/$DMG_NAME"
    DMG_SIZE=$(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)
    echo ""
    echo "  DMG:  $OUTPUT_DIR/$DMG_NAME"
    echo "  Size: $DMG_SIZE"
    echo ""
fi

echo "Done!"
