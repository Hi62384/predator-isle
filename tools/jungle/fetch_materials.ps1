$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jungleRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$jungleIds=@('Ground023','Rock064')
$jungleCache=Join-Path $jungleRoot '.godot\jungle_downloads'
New-Item -ItemType Directory -Force -Path $jungleCache | Out-Null
$jungleRecords=@()
foreach($jungleId in $jungleIds){
    $jungleMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$jungleId+'&include=downloadData')
    $jungleAsset=$jungleMetadata.foundAssets | Where-Object assetId -eq $jungleId
    $jungleDownload=$jungleAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $jungleDownload -or $jungleDownload.size -ge 100000000){throw ('Unexpected download: '+$jungleId)}
    $jungleZip=Join-Path $jungleCache $jungleDownload.fileName
    if(-not (Test-Path -LiteralPath $jungleZip) -or (Get-Item -LiteralPath $jungleZip).Length -ne $jungleDownload.size){
        for($jungleAttempt=1;$jungleAttempt -le 3;$jungleAttempt++){
            try {Invoke-WebRequest -Uri $jungleDownload.downloadLink -OutFile $jungleZip -UseBasicParsing;break}
            catch {if($jungleAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $jungleZip).Length -ne $jungleDownload.size){throw ('Incomplete download: '+$jungleId)}
    $jungleDestination=Join-Path $jungleRoot ('assets\textures\jungle\'+$jungleId)
    New-Item -ItemType Directory -Force -Path $jungleDestination | Out-Null
    $jungleArchive=[IO.Compression.ZipFile]::OpenRead($jungleZip)
    $jungleMaps=@()
    try {
        foreach($jungleMap in @('Color','NormalGL','Roughness')){
            $jungleName=$jungleId+'_2K-JPG_'+$jungleMap+'.jpg'
            $jungleEntry=$jungleArchive.Entries | Where-Object Name -eq $jungleName
            if(-not $jungleEntry){throw ('Missing map: '+$jungleName)}
            $jungleTarget=Join-Path $jungleDestination $jungleName
            if(-not (Test-Path -LiteralPath $jungleTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($jungleEntry,$jungleTarget,$false)}
            $jungleMaps+=@{file=$jungleName;sha256=(Get-FileHash -LiteralPath $jungleTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $jungleTarget).Length}
        }
    } finally {$jungleArchive.Dispose()}
    $jungleRecords+=@{id=$jungleId;source=('https://ambientcg.com/a/'+$jungleId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$jungleAsset.creationMethod;download=$jungleDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $jungleZip -Algorithm SHA256).Hash;maps=$jungleMaps}
    Write-Output ('Downloaded and checked '+$jungleId)
}
# Generated provenance, not hand-maintained source.
$jungleRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $jungleRoot 'data\jungle_material_sources.json') -Encoding UTF8
