# =============================================================================
# pack-banks.ps1
# Packs all preset sample folders into ONE encrypted .banks file.
# Users cannot extract or reuse the .wav files - only the plugin can read it.
#
#   Documents\Synthlen Khmer\banks\<Preset>\**\*.wav
#       -> vst\SynthlenKhmer.banks   (single encrypted blob)
#
#   powershell -ExecutionPolicy Bypass -File .\pack-banks.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\vst
$banksSource = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Synthlen Khmer\banks"
if (-not (Test-Path $banksSource)) {
    $banksSource = Join-Path $root "banks"
}
$outFile = Join-Path $root "SynthlenKhmer.banks"

if (-not (Test-Path $banksSource)) {
    Write-Host "No banks folder found - nothing to pack." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Packing banks from: $banksSource" -ForegroundColor Cyan
Write-Host "Output: $outFile" -ForegroundColor Cyan
Write-Host ""

# Fast packer written in C#
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class BankPacker
{
    // XOR key - must match the C++ side (kPackKey in PluginProcessor.cpp)
    static readonly byte[] Key = Encoding.ASCII.GetBytes("SynKh2024_BankPack_Secret!");

    public static int Pack(string banksDir, string outPath)
    {
        var names = new List<string>();   // "Preset/filename.wav"
        var paths = new List<string>();   // full path on disk
        var sizes = new List<long>();

        foreach (var presetDir in Directory.GetDirectories(banksDir))
        {
            string preset = Path.GetFileName(presetDir);
            foreach (var f in Directory.GetFiles(presetDir, "*.*", SearchOption.AllDirectories))
            {
                string ext = Path.GetExtension(f).ToLowerInvariant();
                if (ext != ".wav" && ext != ".aif" && ext != ".aiff" && ext != ".flac") continue;
                names.Add(preset + "/" + Path.GetFileName(f));
                paths.Add(f);
                sizes.Add(new FileInfo(f).Length);
            }
        }

        // Compute header size: magic(8) + count(4) + per-entry(4+nameBytes+8+8)
        long headerSize = 8 + 4;
        var nameBytes = new List<byte[]>();
        for (int i = 0; i < names.Count; i++)
        {
            var nb = Encoding.UTF8.GetBytes(names[i]);
            nameBytes.Add(nb);
            headerSize += 4 + nb.Length + 8 + 8;
        }

        using (var outStream = new FileStream(outPath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
        using (var w = new BinaryWriter(outStream))
        {
            // Header
            w.Write(Encoding.ASCII.GetBytes("SYNKB1\0\0"));
            w.Write(names.Count);
            long offset = headerSize;
            for (int i = 0; i < names.Count; i++)
            {
                w.Write(nameBytes[i].Length);
                w.Write(nameBytes[i]);
                w.Write(offset);
                w.Write(sizes[i]);
                offset += sizes[i];
            }

            // Data blobs (XOR-encrypted, key restarts per file)
            var buf = new byte[1 << 20];
            for (int i = 0; i < paths.Count; i++)
            {
                long filePos = 0;
                using (var inStream = new FileStream(paths[i], FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
                {
                    int read;
                    while ((read = inStream.Read(buf, 0, buf.Length)) > 0)
                    {
                        for (int b = 0; b < read; b++)
                            buf[b] ^= Key[(filePos + b) % Key.Length];
                        w.Write(buf, 0, read);
                        filePos += read;
                    }
                }
            }
        }
        return names.Count;
    }
}
"@

$count = [BankPacker]::Pack($banksSource, $outFile)
$size = (Get-Item $outFile).Length / 1MB

Write-Host "Packed $count sample(s) into SynthlenKhmer.banks" -ForegroundColor Green
Write-Host ("Size: {0:N1} MB" -f $size) -ForegroundColor Yellow
Write-Host ""
