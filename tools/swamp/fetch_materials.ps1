$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$swampRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$swampIds=@('Ground036','Ground083','Ground071')
$swampCache=Join-Path $swampRoot '.godot\swamp_downloads'
New-Item -ItemType Directory -Force -Path $swampCache | Out-Null
$swampRecords=@()
foreach($swampId in $swampIds){
    $swampMetadata=Invoke-RestMethod ('https://ambientcg.com/api/v2/full_json?id='+$swampId+'&include=downloadData')
    $swampAsset=$swampMetadata.foundAssets | Where-Object assetId -eq $swampId
    $swampDownload=$swampAsset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '2K-JPG'
    if(-not $swampDownload -or $swampDownload.size -ge 100000000){throw ('Unexpected download: '+$swampId)}
    $swampZip=Join-Path $swampCache $swampDownload.fileName
    if(-not (Test-Path -LiteralPath $swampZip) -or (Get-Item -LiteralPath $swampZip).Length -ne $swampDownload.size){
        for($swampAttempt=1;$swampAttempt -le 3;$swampAttempt++){
            try {Invoke-WebRequest -Uri $swampDownload.downloadLink -OutFile $swampZip -UseBasicParsing;break}
            catch {if($swampAttempt -eq 3){throw}}
        }
    }
    if((Get-Item -LiteralPath $swampZip).Length -ne $swampDownload.size){throw ('Incomplete download: '+$swampId)}
    $swampDestination=Join-Path $swampRoot ('assets\textures\swamp\'+$swampId)
    New-Item -ItemType Directory -Force -Path $swampDestination | Out-Null
    $swampArchive=[IO.Compression.ZipFile]::OpenRead($swampZip)
    $swampMaps=@()
    try {
        foreach($swampMap in @('Color','NormalGL','Roughness')){
            $swampName=$swampId+'_2K-JPG_'+$swampMap+'.jpg'
            $swampEntry=$swampArchive.Entries | Where-Object Name -eq $swampName
            if(-not $swampEntry){throw ('Missing map: '+$swampName)}
            $swampTarget=Join-Path $swampDestination $swampName
            if(-not (Test-Path -LiteralPath $swampTarget)){[IO.Compression.ZipFileExtensions]::ExtractToFile($swampEntry,$swampTarget,$false)}
            $swampMaps+=@{file=$swampName;sha256=(Get-FileHash -LiteralPath $swampTarget -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $swampTarget).Length}
        }
    } finally {$swampArchive.Dispose()}
    $swampRecords+=@{id=$swampId;source=('https://ambientcg.com/a/'+$swampId);license='CC0-1.0';license_url='https://docs.ambientcg.com/license/';creation_method=$swampAsset.creationMethod;download=$swampDownload.downloadLink;archive_sha256=(Get-FileHash -LiteralPath $swampZip -Algorithm SHA256).Hash;maps=$swampMaps}
    Write-Output ('Downloaded and checked '+$swampId)
}
# Generated provenance, not hand-maintained source.
$swampRecords | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $swampRoot 'data\swamp_material_sources.json') -Encoding UTF8
