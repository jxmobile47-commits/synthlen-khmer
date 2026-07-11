#!/bin/bash
# Synthlen Khmer - macOS One-Click Installer
# Usage: bash mac-install.sh
# This script: installs p7zip → downloads → recombines → extracts → installs

set -e

VERSION="1.0.0"
REPO="jxmobile47-commits/synthlen-khmer"
TAG="v1.0.0-macos"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"
TMP_DIR="/tmp/synthlen-khmer-install"

echo ""
echo "========================================"
echo "  Synthlen Khmer - macOS Installer"
echo "========================================"
echo ""

# Step 1: Install p7zip if not present
if ! command -v 7z &> /dev/null; then
    echo "[1/5] Installing p7zip..."
    if ! command -v brew &> /dev/null; then
        echo "  Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
    fi
    brew install p7zip || true
else
    echo "[1/5] p7zip already installed"
fi

# Step 2: Download parts
echo ""
echo "[2/5] Downloading installer parts..."
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Try downloading split parts first
curl -L -o "SynthlenKhmer-Setup-$VERSION.7z.partaa" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z.partaa" 2>&1 | tail -1
curl -L -o "SynthlenKhmer-Setup-$VERSION.7z.partab" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z.partab" 2>&1 | tail -1

# Check if parts exist and have content
PART_A_SIZE=$(stat -f%z "SynthlenKhmer-Setup-$VERSION.7z.partaa" 2>/dev/null || echo 0)
if [ "$PART_A_SIZE" -lt 1000000 ]; then
    echo "  Split parts not found, trying single file..."
    curl -L -o "SynthlenKhmer-Setup-$VERSION.7z" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z" 2>&1 | tail -1
else
    # Step 3: Recombine parts
    echo ""
    echo "[3/5] Recombining parts..."
    cat "SynthlenKhmer-Setup-$VERSION.7z.parta"* > "SynthlenKhmer-Setup-$VERSION.7z"
    rm -f "SynthlenKhmer-Setup-$VERSION.7z.parta"*
fi

# Step 4: Extract
echo ""
echo "[4/5] Extracting (this may take a few minutes)..."
rm -rf "extracted"
mkdir -p "extracted"
cd "extracted"
7z x "../SynthlenKhmer-Setup-$VERSION.7z" -y > /dev/null 2>&1

# Step 5: Install
echo ""
echo "[5/5] Installing (admin password required)..."
sudo bash ./install.sh

# Cleanup
cd /
rm -rf "$TMP_DIR"

echo ""
echo "========================================"
echo "  Installation Complete!"
echo "========================================"
echo ""
echo "  VST3:       /Library/Audio/Plug-Ins/VST3/Synthlen Khmer.vst3"
echo "  Standalone: /Applications/Synthlen Khmer.app"
echo "  Banks:      /Library/Application Support/Synthlen Khmer/"
echo ""
echo "  Open Synthlen Khmer from Applications folder."
echo ""
