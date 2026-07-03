#!/bin/bash
# Synthlen Khmer - Pack banks for macOS build
# Same format as pack-banks.ps1 but runs on macOS/Linux
# Packs all .wav files from banks/<Preset>/ into one XOR-encrypted .banks file
#
# Usage: bash pack-banks.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BANKS_DIR="$PROJECT_ROOT/banks"
OUTPUT="$PROJECT_ROOT/SynthlenKhmer.banks"
KEY="SynKh2024_BankPack_Secret!"

if [ ! -d "$BANKS_DIR" ]; then
    echo "ERROR: banks/ folder not found at $BANKS_DIR"
    exit 1
fi

echo ""
echo "========================================"
echo "  Packing encrypted bank pack (macOS)"
echo "========================================"
echo ""

# Collect all wav files from preset subdirectories
ENTRIES=()
PRESET_DIRS=()

for d in "$BANKS_DIR"/*/; do
    if [ -d "$d" ]; then
        PRESET_DIRS+=("$d")
    fi
done

if [ ${#PRESET_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No preset folders found in banks/"
    exit 1
fi

# Count total files
TOTAL=0
for d in "${PRESET_DIRS[@]}"; do
    COUNT=$(find "$d" -maxdepth 1 -name "*.wav" | wc -l)
    TOTAL=$((TOTAL + COUNT))
    PRESET_NAME=$(basename "$d")
    echo "  Preset: $PRESET_NAME ($COUNT files)"
done

echo ""
echo "  Total files: $TOTAL"
echo ""

if [ $TOTAL -eq 0 ]; then
    echo "ERROR: No .wav files found"
    exit 1
fi

# Build the .banks file using Python for binary handling
python3 << 'PYTHON'
import os
import struct
import sys

banks_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "banks")
output = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SynthlenKhmer.banks")
key = b"SynKh2024_BankPack_Secret!"

def xor_encrypt(data, key):
    return bytes(data[i] ^ key[i % len(key)] for i in range(len(data)))

# Collect entries: (preset/filename, filepath)
entries = []
for preset_name in sorted(os.listdir(banks_dir)):
    preset_dir = os.path.join(banks_dir, preset_name)
    if not os.path.isdir(preset_dir):
        continue
    for fname in sorted(os.listdir(preset_dir)):
        if fname.lower().endswith(('.wav', '.aif', '.aiff', '.flac')):
            entries.append((preset_name + "/" + fname, os.path.join(preset_dir, fname)))

print(f"  Total entries: {len(entries)}")

# Write header + index, then data
with open(output, 'wb') as f:
    # Magic
    f.write(b"SYNKB1\x00\x00")
    # Count
    f.write(struct.pack('<i', len(entries)))

    # We need to compute offsets: header(8) + count(4) + per-entry: nameLen(4) + name + offset(8) + size(8)
    # First pass: compute index size
    index_size = 0
    for name, _ in entries:
        name_bytes = name.encode('utf-8')
        index_size += 4 + len(name_bytes) + 8 + 8

    # Data starts after header + count + index
    data_offset = 8 + 4 + index_size

    # Write index
    current_offset = data_offset
    for name, filepath in entries:
        name_bytes = name.encode('utf-8')
        with open(filepath, 'rb') as wf:
            raw = wf.read()
        encrypted = xor_encrypt(raw, key)

        f.write(struct.pack('<i', len(name_bytes)))
        f.write(name_bytes)
        f.write(struct.pack('<q', current_offset))
        f.write(struct.pack('<q', len(encrypted)))

        current_offset += len(encrypted)

    # Write data
    for name, filepath in entries:
        with open(filepath, 'rb') as wf:
            raw = wf.read()
        encrypted = xor_encrypt(raw, key)
        f.write(encrypted)

size_mb = os.path.getsize(output) / (1024 * 1024)
print(f"  -> Created: {output}")
print(f"  -> Size: {size_mb:.1f} MB (encrypted)")
PYTHON

echo ""
echo "  Done!"
echo ""
