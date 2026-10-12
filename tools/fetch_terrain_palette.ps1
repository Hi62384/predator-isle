param([string[]]$AssetIds = @('Ground037','Ground048','Gravel020','Rock035'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectPath = Split-Path -Parent $PSScriptRoot
$downloadDir = Join-Path ([IO.Path]::GetTempPath()) ('predator-palette-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $downloadDir | Out-Null
foreach ($asset in $AssetIds) {
    $archivePath = Join-Path $downloadDir ($asset + '.zip')
    $uri = 'https://ambientcg.com/get?file=' + $asset + '_2K-JPG.zip'
    & curl.exe -L --fail --retry 2 --silent --show-error $uri -o $archivePath
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $asset" }
    $destination = Join-Path $projectPath ('assets/textures/ambientcg/' + $asset)
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.Name -match '_(Color|NormalGL|Roughness)\.jpg$') {
                $targetFile = Join-Path $destination $entry.Name
                if (-not (Test-Path -LiteralPath $targetFile)) {
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetFile)
                }
            }
        }
    } finally { $archive.Dispose() }
    Write-Output "$asset extracted Color/NormalGL/Roughness 2K originals"
}
Write-Output "Development archives retained outside project at $downloadDir"
