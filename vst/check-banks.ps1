$key = 'SynKh2024_BankPack_Secret!'
$keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$f = [System.IO.File]::OpenRead('C:\Users\User\Desktop\UI UX Desing\vst\SynthlenKhmer.banks')
$br = New-Object System.IO.BinaryReader($f)
$magic = $br.ReadString()
$count = $br.ReadInt32()
Write-Host "Magic: $magic"
Write-Host "Preset count: $count"
for ($i = 0; $i -lt $count; $i++) {
    $nameLen = $br.ReadInt32()
    $nameBytes = $br.ReadBytes($nameLen)
    $name = [System.Text.Encoding]::UTF8.GetString($nameBytes)
    $fileLen = $br.ReadInt32()
    $data = $br.ReadBytes($fileLen)
    Write-Host "  [$i] $name ($fileLen bytes)"
}
$f.Close()
