$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$beachRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$beachIds=@('Ground055S','Ground059','Ground060','Ground080')
$beachCache=Join-Path $beachRoot '.godot\beach_downloads'
New-Item -ItemType Directory -Force -Path $beachCache | Out-Null
$beachRecords=@()
foreach($beachId in $beachIds){
    $beachMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$beachId+'&include=downloadData')
    $beachAsset=$beachMetadata.foundAssets | Where-Object assetId -eq $beachId
    $beachDownload=$beachAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $beachDownload -or $beachDownload.size -ge 100000000){throw ('Unexpected download: '+$beachId)}
    $beachZip=Join-Path $beachCache $beachDownload.fileName
    if(-not (Test-Path -LiteralPath $beachZip) -or (Get-Item -LiteralPath $beachZip).Length -ne $beachDownload.size){
        for($beachAttempt=1;$beachAttempt -le 3;$beachAttempt++){
            try {Invoke-WebRequest -Uri $beachDownload.downloadLink -OutFile $beachZip -UseBasicParsing;break}
            catch {if($beachAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $beachZip).Length -ne $beachDownload.size){throw ('Incomplete download: '+$beachId)}
    $beachDestination=Join-Path $beachRoot ('assets\textures\beach\'+$beachId)
    New-Item -ItemType Directory -Force -Path $beachDestination | Out-Null
    $beachArchive=[IO.Compression.ZipFile]::OpenRead($beachZip)
    $beachMaps=@()
    try {
        foreach($beachMap in @('Color','NormalGL','Roughness')){
            $beachName=$beachId+'_2K-JPG_'+$beachMap+'.jpg'
            $beachEntry=$beachArchive.Entries | Where-Object Name -eq $beachName
            if(-not $beachEntry){throw ('Missing map: '+$beachName)}
            $beachTarget=Join-Path $beachDestination $beachName
            if(-not (Test-Path -LiteralPath $beachTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($beachEntry,$beachTarget,$false)}
            $beachMaps+=@{file=$beachName;sha256=(Get-FileHash -LiteralPath $beachTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $beachTarget).Length}
        }
    } finally {$beachArchive.Dispose()}
    $beachRecords+=@{id=$beachId;source=('https://ambientcg.com/a/'+$beachId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$beachAsset.creationMethod;download=$beachDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $beachZip -Algorithm SHA256).Hash;maps=$beachMaps}
    Write-Output ('Downloaded and checked '+$beachId)
}
# Generated provenance, not hand-maintained source.
$beachRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $beachRoot 'data\beach_material_sources.json') -Encoding UTF8
