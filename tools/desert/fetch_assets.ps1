# Development only. Run only as part of a locally approved validation batch.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$source = Join-Path $project 'assets\textures\desert'
$plan = Get-Content -LiteralPath (Join-Path $source 'download_plan.json') -Raw | ConvertFrom-Json
$archiveRoot = Join-Path $project 'tools\desert\artifacts\downloads'
New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
$records = @()
foreach ($asset in $plan) {
    if ($asset.id -notin @('Ground092A','Ground054','Gravel020','Rock061','Ground031','Ground033')) { throw 'Unexpected asset identifier' }
    if ($asset.archive_name -ne ($asset.id + '_2K-JPG.zip')) { throw 'Unexpected archive filename' }
    $uri = [uri]$asset.download
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'ambientcg.com') { throw 'Expected verified official ambientCG URL' }
    $destination = Join-Path $source $asset.id
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $archivePath = Join-Path $archiveRoot $asset.archive_name
    if (-not (Test-Path -LiteralPath $archivePath)) {
        Invoke-WebRequest -UseBasicParsing -Uri $uri.AbsoluteUri -OutFile $archivePath
    }
    if ((Get-Item -LiteralPath $archivePath).Length -ne [long]$asset.archive_bytes) { throw "Archive byte count differs for $($asset.id)" }
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    $maps = @()
    try {
        foreach ($entry in $archive.Entries) {
            # No arbitrary archive paths. Extract only exact three map names.
            foreach ($kind in @('Color','NormalGL','Roughness')) {
                $wanted = $asset.id + '_2K-JPG_' + $kind + '.jpg'
                if ($entry.FullName -eq $wanted) {
                    $target = Join-Path $destination $wanted
                    if (-not (Test-Path -LiteralPath $target)) { [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target) }
                    $hash = [Security.Cryptography.SHA256]::Create()
                    $stream = $entry.Open()
                    try { $expectedHash = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLower() }
                    finally { $stream.Dispose(); $hash.Dispose() }
                    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLower()
                    if ($actualHash -ne $expectedHash) { throw ('Preserved existing map differs from its source archive: ' + $wanted) }
                    $maps += @{ file = $wanted; sha256 = $actualHash; bytes = (Get-Item -LiteralPath $target).Length }
                }
            }
        }
    } finally { $archive.Dispose() }
    if ($maps.Count -ne 3) { throw "Expected three maps for $($asset.id)" }
    $records += @{ id = $asset.id; source = $asset.source; download = $asset.download; license = $asset.license; license_url = $asset.license_url; downloaded_utc = [DateTime]::UtcNow.ToString('o'); archive_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLower(); maps = $maps }
    $records | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $source 'downloaded_manifest.json')
    Write-Output "Verified $($asset.id): original Color, NormalGL, Roughness"
}
