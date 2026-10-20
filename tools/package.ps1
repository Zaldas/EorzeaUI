# Builds EorzeaUI-<version>.zip with EorzeaUI\ at the archive root, ready to unzip into Interface\AddOns\.
# Dev-only files are left out.
param(
    [string]$OutDir = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$addonRoot = Split-Path -Parent $PSScriptRoot
$addonName = Split-Path -Leaf $addonRoot
$exclude = @('.git', '.gitignore', '.gitattributes', '.vscode', '.luarc.json', 'CLAUDE.md', 'tools', 'docs')

$tocLine = Select-String -Path (Join-Path $addonRoot "$addonName.toc") -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
$version = if ($tocLine) { $tocLine.Matches[0].Groups[1].Value.Trim() } else { 'dev' }

$zipPath = Join-Path $OutDir ('{0}-{1}.zip' -f $addonName, $version)
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$files = Get-ChildItem $addonRoot -Recurse -File -Force | Where-Object {
    $relative = $_.FullName.Substring($addonRoot.Length + 1)
    $exclude -notcontains ($relative -split '\\')[0]
}

# Entry names use forward slashes; backslash entries extract as flat files on some unzippers.
$count = 0
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($addonRoot.Length + 1)
        $entry = '{0}/{1}' -f $addonName, ($relative -replace '\\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry, 'Optimal')
        $count++
    }
}
finally {
    $zip.Dispose()
}

Write-Host ('Packaged {0} files into {1}' -f $count, $zipPath)
