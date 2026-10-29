$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$forestRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$forestIds=@('Ground070','Ground077')
$forestCache=Join-Path $forestRoot '.godot\forest_downloads'
New-Item -ItemType Directory -Force -Path $forestCache | Out-Null
$forestRecords=@()
foreach($forestId in $forestIds){
    $forestMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$forestId+'&include=downloadData')
    $forestAsset=$forestMetadata.foundAssets | Where-Object assetId -eq $forestId
    $forestDownload=$forestAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $forestDownload -or $forestDownload.size -ge 100000000){throw ('Unexpected download: '+$forestId)}
    $forestZip=Join-Path $forestCache $forestDownload.fileName
    if(-not (Test-Path -LiteralPath $forestZip) -or (Get-Item -LiteralPath $forestZip).Length -ne $forestDownload.size){
        for($forestAttempt=1;$forestAttempt -le 3;$forestAttempt++){
            try {Invoke-WebRequest -Uri $forestDownload.downloadLink -OutFile $forestZip -UseBasicParsing;break}
            catch {if($forestAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $forestZip).Length -ne $forestDownload.size){throw ('Incomplete download: '+$forestId)}
    $forestDestination=Join-Path $forestRoot ('assets\textures\forest\'+$forestId)
    New-Item -ItemType Directory -Force -Path $forestDestination | Out-Null
    $forestArchive=[IO.Compression.ZipFile]::OpenRead($forestZip)
    $forestMaps=@()
    try {
        foreach($forestMap in @('Color','NormalGL','Roughness')){
            $forestName=$forestId+'_2K-JPG_'+$forestMap+'.jpg'
            $forestEntry=$forestArchive.Entries | Where-Object Name -eq $forestName
            if(-not $forestEntry){throw ('Missing map: '+$forestName)}
            $forestTarget=Join-Path $forestDestination $forestName
            if(-not (Test-Path -LiteralPath $forestTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($forestEntry,$forestTarget,$false)}
            $forestMaps+=@{file=$forestName;sha256=(Get-FileHash -LiteralPath $forestTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $forestTarget).Length}
        }
    } finally {$forestArchive.Dispose()}
    $forestRecords+=@{id=$forestId;source=('https://ambientcg.com/a/'+$forestId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$forestAsset.creationMethod;download=$forestDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $forestZip -Algorithm SHA256).Hash;maps=$forestMaps}
    Write-Output ('Downloaded and checked '+$forestId)
}
# Generated provenance, not hand-maintained source.
$forestRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $forestRoot 'data\forest_material_sources.json') -Encoding UTF8
