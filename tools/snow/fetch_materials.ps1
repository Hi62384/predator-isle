$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$snowRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$snowIds=@('Snow005','Snow006','Snow014','Ice004')
$snowCache=Join-Path $snowRoot '.godot\snow_downloads'
New-Item -ItemType Directory -Force -Path $snowCache | Out-Null
$snowRecords=@()
foreach($snowId in $snowIds){
    $snowMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$snowId+'&include=downloadData')
    $snowAsset=$snowMetadata.foundAssets | Where-Object assetId -eq $snowId
    $snowDownload=$snowAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $snowDownload -or $snowDownload.size -ge 100000000){throw ('Unexpected download: '+$snowId)}
    $snowZip=Join-Path $snowCache $snowDownload.fileName
    if(-not (Test-Path -LiteralPath $snowZip)){Invoke-WebRequest -Uri $snowDownload.downloadLink -OutFile $snowZip -UseBasicParsing}
    if((Get-Item -LiteralPath $snowZip).Length -ne $snowDownload.size){throw ('Incomplete download: '+$snowId)}
    $snowDestination=Join-Path $snowRoot ('assets\textures\snow\'+$snowId)
    New-Item -ItemType Directory -Force -Path $snowDestination | Out-Null
    $snowArchive=[IO.Compression.ZipFile]::OpenRead($snowZip)
    $snowMaps=@()
    try {
        foreach($snowMap in @('Color','NormalGL','Roughness','Displacement')){
            $snowName=$snowId+'_2K-JPG_'+$snowMap+'.jpg'
            $snowEntry=$snowArchive.Entries | Where-Object Name -eq $snowName
            if(-not $snowEntry){throw ('Missing map: '+$snowName)}
            $snowTarget=Join-Path $snowDestination $snowName
            if(-not (Test-Path -LiteralPath $snowTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($snowEntry,$snowTarget,$false)}
            $snowMaps+=@{file=$snowName;sha256=(Get-FileHash -LiteralPath $snowTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $snowTarget).Length}
        }
    } finally {$snowArchive.Dispose()}
    $snowRecords+=@{id=$snowId;source=('https://ambientcg.com/a/'+$snowId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$snowAsset.creationMethod;download=$snowDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $snowZip -Algorithm SHA256).Hash;maps=$snowMaps}
    Write-Output ('Downloaded and checked '+$snowId)
}
# Generated provenance, not hand-maintained source.
$snowRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $snowRoot 'data\snow_material_sources.json') -Encoding UTF8
