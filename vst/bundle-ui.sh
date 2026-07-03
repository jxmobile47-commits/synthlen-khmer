#!/bin/bash
# Synthlen Khmer - Bundle UI for macOS build
# Copies HTML + images + manifest into ui/ folder
#
# Usage: bash bundle-ui.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
UI_DIR="$PROJECT_ROOT/ui"

echo ""
echo "========================================"
echo "  Bundling Web UI (macOS)"
echo "========================================"
echo ""

mkdir -p "$UI_DIR"

# Copy main HTML
PARENT_DIR="$(dirname "$PROJECT_ROOT")"
HTML_SRC="$PARENT_DIR/synthlen-khmer.html"
if [ -f "$HTML_SRC" ]; then
    cp "$HTML_SRC" "$UI_DIR/"
    echo "  -> Copied synthlen-khmer.html"
else
    echo "  WARNING: synthlen-khmer.html not found at $HTML_SRC"
fi

# Copy uploads folder (images)
UPLOADS_SRC="$PARENT_DIR/uploads"
if [ -d "$UPLOADS_SRC" ]; then
    cp -r "$UPLOADS_SRC" "$UI_DIR/"
    echo "  -> Copied uploads/"
fi

# Copy manifest if exists
MANIFEST_SRC="$PARENT_DIR/manifest.json"
if [ -f "$MANIFEST_SRC" ]; then
    cp "$MANIFEST_SRC" "$UI_DIR/"
    echo "  -> Copied manifest.json"
fi

echo ""
echo "  UI bundled at: $UI_DIR"
echo ""
