$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$savannaRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$savannaIds=@('Ground030','Grass003','Ground105','Ground026','Rock042L','Rock055')
$savannaCache=Join-Path $savannaRoot '.godot\savanna_downloads'
New-Item -ItemType Directory -Force -Path $savannaCache | Out-Null
$savannaRecords=@()
foreach($savannaId in $savannaIds){
    $savannaMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$savannaId+'&include=downloadData')
    $savannaAsset=$savannaMetadata.foundAssets | Where-Object assetId -eq $savannaId
    $savannaDownload=$savannaAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $savannaDownload -or $savannaDownload.size -ge 100000000){throw ('Unexpected download: '+$savannaId)}
    $savannaZip=Join-Path $savannaCache $savannaDownload.fileName
    if(-not (Test-Path -LiteralPath $savannaZip) -or (Get-Item -LiteralPath $savannaZip).Length -ne $savannaDownload.size){
        for($savannaAttempt=1;$savannaAttempt -le 3;$savannaAttempt++){
            try {Invoke-WebRequest -Uri $savannaDownload.downloadLink -OutFile $savannaZip -UseBasicParsing;break}
            catch {if($savannaAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $savannaZip).Length -ne $savannaDownload.size){throw ('Incomplete download: '+$savannaId)}
    $savannaDestination=Join-Path $savannaRoot ('assets\textures\savanna\'+$savannaId)
    New-Item -ItemType Directory -Force -Path $savannaDestination | Out-Null
    $savannaArchive=[IO.Compression.ZipFile]::OpenRead($savannaZip)
    $savannaMaps=@()
    try {
        foreach($savannaMap in @('Color','NormalGL','Roughness')){
            $savannaName=$savannaId+'_2K-JPG_'+$savannaMap+'.jpg'
            $savannaEntry=$savannaArchive.Entries | Where-Object Name -eq $savannaName
            if(-not $savannaEntry){throw ('Missing map: '+$savannaName)}
            $savannaTarget=Join-Path $savannaDestination $savannaName
            if(-not (Test-Path -LiteralPath $savannaTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($savannaEntry,$savannaTarget,$false)}
            $savannaMaps+=@{file=$savannaName;sha256=(Get-FileHash -LiteralPath $savannaTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $savannaTarget).Length}
        }
    } finally {$savannaArchive.Dispose()}
    $savannaRecords+=@{id=$savannaId;source=('https://ambientcg.com/a/'+$savannaId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$savannaAsset.creationMethod;download=$savannaDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $savannaZip -Algorithm SHA256).Hash;maps=$savannaMaps}
    Write-Output ('Downloaded and checked '+$savannaId)
}
# Generated provenance, not hand-maintained source.
$savannaRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $savannaRoot 'data\savanna_material_sources.json') -Encoding UTF8
