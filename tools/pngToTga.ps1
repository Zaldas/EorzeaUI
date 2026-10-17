param([string]$SrcRoot, [string]$DstRoot, [string[]]$Files)
# Converts PNGs to 32-bit uncompressed bottom-up TGA (descriptor 0x08), preserving alpha.
Add-Type -AssemblyName System.Drawing
foreach ($rel in $Files) {
    $src = Join-Path $SrcRoot $rel
    $dst = Join-Path $DstRoot ([System.IO.Path]::ChangeExtension($rel, '.tga'))
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap $src
    $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $raw = New-Object byte[] ($stride * $bmp.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
    $bmp.UnlockBits($data)
    $w = $bmp.Width; $h = $bmp.Height
    $bmp.Dispose()

    $out = New-Object System.IO.MemoryStream
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $w -band 0xFF; $header[13] = ($w -shr 8) -band 0xFF
    $header[14] = $h -band 0xFF; $header[15] = ($h -shr 8) -band 0xFF
    $header[16] = 32
    $header[17] = 0x08
    $out.Write($header, 0, 18)
    for ($y = $h - 1; $y -ge 0; $y--) {
        $out.Write($raw, $y * $stride, $w * 4)
    }
    [System.IO.File]::WriteAllBytes($dst, $out.ToArray())
    "{0} -> {1} ({2}x{3})" -f $rel, $dst, $w, $h
}
