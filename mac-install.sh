#!/bin/bash
# Synthlen Khmer - macOS .pkg Builder
# Usage: bash mac-install.sh
# Downloads, extracts, and builds a .pkg installer you can share via USB
# After building, you can also install directly from this script

set -e

VERSION="1.0.0"
REPO="jxmobile47-commits/synthlen-khmer"
TAG="v1.0.0-macos"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"
TMP_DIR="/tmp/synthlen-khmer-build"
OUTPUT_DIR="$HOME/Desktop"

echo ""
echo "========================================"
echo "  Synthlen Khmer - macOS .pkg Builder"
echo "========================================"
echo ""

# Step 1: Install p7zip if not present
if ! command -v 7z &> /dev/null; then
    echo "[1/6] Installing p7zip..."
    if ! command -v brew &> /dev/null; then
        echo "  Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
    fi
    brew install p7zip || true
else
    echo "[1/6] p7zip already installed"
fi

# Step 2: Download parts
echo ""
echo "[2/6] Downloading installer parts..."
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

curl -L -o "SynthlenKhmer-Setup-$VERSION.7z.partaa" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z.partaa" 2>&1 | tail -1
curl -L -o "SynthlenKhmer-Setup-$VERSION.7z.partab" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z.partab" 2>&1 | tail -1

PART_A_SIZE=$(stat -f%z "SynthlenKhmer-Setup-$VERSION.7z.partaa" 2>/dev/null || echo 0)
if [ "$PART_A_SIZE" -lt 1000000 ]; then
    echo "  Split parts not found, trying single file..."
    curl -L -o "SynthlenKhmer-Setup-$VERSION.7z" "$BASE_URL/SynthlenKhmer-Setup-$VERSION.7z" 2>&1 | tail -1
else
    # Step 3: Recombine parts
    echo ""
    echo "[3/6] Recombining parts..."
    cat "SynthlenKhmer-Setup-$VERSION.7z.parta"* > "SynthlenKhmer-Setup-$VERSION.7z"
    rm -f "SynthlenKhmer-Setup-$VERSION.7z.parta"*
fi

# Step 4: Extract
echo ""
echo "[4/6] Extracting (this may take a few minutes)..."
rm -rf "extracted"
mkdir -p "extracted"
cd "extracted"
7z x "../SynthlenKhmer-Setup-$VERSION.7z" -y > /dev/null 2>&1

# Step 5: Build .pkg
echo ""
echo "[5/6] Building .pkg installer..."

PKG_ROOT="$TMP_DIR/pkg_root"
PKG_SCRIPTS="$TMP_DIR/pkg_scripts"
rm -rf "$PKG_ROOT" "$PKG_SCRIPTS"
mkdir -p "$PKG_ROOT/Library/Audio/Plug-Ins/VST3"
mkdir -p "$PKG_ROOT/Applications"
mkdir -p "$PKG_SCRIPTS"

# Copy VST3 (includes bank)
if [ -d "Synthlen Khmer.vst3" ]; then
    cp -R "Synthlen Khmer.vst3" "$PKG_ROOT/Library/Audio/Plug-Ins/VST3/"
    echo "  VST3 copied (with bank)"
else
    echo "  ERROR: VST3 not found!"
    exit 1
fi

# Copy Standalone
if [ -d "Synthlen Khmer.app" ]; then
    cp -R "Synthlen Khmer.app" "$PKG_ROOT/Applications/"
    echo "  Standalone copied"
else
    echo "  WARNING: Standalone not found"
fi

# Create postinstall script
cat > "$PKG_SCRIPTS/postinstall" << 'POSTINSTALL'
#!/bin/bash
SHARED_DIR="/Library/Application Support/Synthlen Khmer"
mkdir -p "$SHARED_DIR"
VST3_BANK="/Library/Audio/Plug-Ins/VST3/Synthlen Khmer.vst3/Contents/Resources/SynthlenKhmer.banks"
if [ -f "$VST3_BANK" ]; then
    cp "$VST3_BANK" "$SHARED_DIR/SynthlenKhmer.banks"
    echo "Copied bank to $SHARED_DIR"
fi
exit 0
POSTINSTALL
chmod +x "$PKG_SCRIPTS/postinstall"

# Build component package
pkgbuild \
    --root "$PKG_ROOT" \
    --scripts "$PKG_SCRIPTS" \
    --identifier "com.synthlen.khmer" \
    --version "$VERSION" \
    "$TMP_DIR/SynthlenKhmer.pkg"

# Build product archive (distributable .pkg)
PKG_FILE="$OUTPUT_DIR/SynthlenKhmer-Setup-$VERSION.pkg"
productbuild \
    --package "$TMP_DIR/SynthlenKhmer.pkg" \
    "$PKG_FILE"

PKG_SIZE=$(du -h "$PKG_FILE" | cut -f1)
echo "  .pkg created: $PKG_FILE ($PKG_SIZE)"

# Step 6: Ask to install or just exit
echo ""
echo "[6/6] Done!"
echo ""
echo "========================================"
echo "  .pkg Builder Complete!"
echo "========================================"
echo ""
echo "  File: $PKG_FILE"
echo "  Size: $PKG_SIZE"
echo ""
echo "  To install: Double-click the .pkg on your Desktop"
echo "  To share:  Copy the .pkg to USB and give to your friend"
echo ""

# Cleanup
rm -rf "$TMP_DIR"

# Ask if user wants to install now
read -p "Install now? (y/n): " INSTALL_NOW
if [ "$INSTALL_NOW" = "y" ] || [ "$INSTALL_NOW" = "Y" ]; then
    echo "Opening installer..."
    open "$PKG_FILE"
fi

echo ""
echo "Done! You can find the .pkg on your Desktop."
