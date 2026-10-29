$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$mountainRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mountainIds=@('Rock051','Ground108','Gravel040')
$mountainCache=Join-Path $mountainRoot '.godot\mountain_downloads'
New-Item -ItemType Directory -Force -Path $mountainCache | Out-Null
$mountainRecords=@()
foreach($mountainId in $mountainIds){
    $mountainMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$mountainId+'&include=downloadData')
    $mountainAsset=$mountainMetadata.foundAssets | Where-Object assetId -eq $mountainId
    $mountainDownload=$mountainAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $mountainDownload -or $mountainDownload.size -ge 100000000){throw ('Unexpected download: '+$mountainId)}
    $mountainZip=Join-Path $mountainCache $mountainDownload.fileName
    if(-not (Test-Path -LiteralPath $mountainZip) -or (Get-Item -LiteralPath $mountainZip).Length -ne $mountainDownload.size){
        for($mountainAttempt=1;$mountainAttempt -le 3;$mountainAttempt++){
            try {Invoke-WebRequest -Uri $mountainDownload.downloadLink -OutFile $mountainZip -UseBasicParsing;break}
            catch {if($mountainAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $mountainZip).Length -ne $mountainDownload.size){throw ('Incomplete download: '+$mountainId)}
    $mountainDestination=Join-Path $mountainRoot ('assets\textures\mountain\'+$mountainId)
    New-Item -ItemType Directory -Force -Path $mountainDestination | Out-Null
    $mountainArchive=[IO.Compression.ZipFile]::OpenRead($mountainZip)
    $mountainMaps=@()
    try {
        foreach($mountainMap in @('Color','NormalGL','Roughness')){
            $mountainName=$mountainId+'_2K-JPG_'+$mountainMap+'.jpg'
            $mountainEntry=$mountainArchive.Entries | Where-Object Name -eq $mountainName
            if(-not $mountainEntry){throw ('Missing map: '+$mountainName)}
            $mountainTarget=Join-Path $mountainDestination $mountainName
            if(-not (Test-Path -LiteralPath $mountainTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($mountainEntry,$mountainTarget,$false)}
            $mountainMaps+=@{file=$mountainName;sha256=(Get-FileHash -LiteralPath $mountainTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $mountainTarget).Length}
        }
    } finally {$mountainArchive.Dispose()}
    $mountainRecords+=@{id=$mountainId;source=('https://ambientcg.com/a/'+$mountainId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$mountainAsset.creationMethod;download=$mountainDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $mountainZip -Algorithm SHA256).Hash;maps=$mountainMaps}
    Write-Output ('Downloaded and checked '+$mountainId)
}
# Generated provenance, not hand-maintained source.
$mountainRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $mountainRoot 'data\mountain_material_sources.json') -Encoding UTF8
