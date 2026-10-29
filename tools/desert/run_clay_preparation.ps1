param([string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe')
# Offline isolated packing in a coordinated slot; existing asset-packer guards.
# Publish only verified new outputs. Never replace an existing material resource.
$ErrorActionPreference = 'Stop'
$desertProject = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$desertFree = [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024
if ($desertFree -lt 768MB) { Write-Output "Clay preparation blocked: free RAM $desertFree bytes; requires 805306368 bytes."; exit 42 }
. (Join-Path $PSScriptRoot 'owned_process.ps1')
$desertOutputs = @('desert_color_polyhaven_clay.res','desert_normal_polyhaven_clay.res','desert_color_roughness_clay.tres','desert_normals_clay.tres')
foreach ($desertOutput in $desertOutputs) {
    if (Test-Path -LiteralPath (Join-Path $desertProject ('materials\' + $desertOutput))) { throw ('Preserving existing clay output: ' + $desertOutput) }
}
$desertRun = Join-Path $PSScriptRoot ('artifacts\current_clay_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
$desertSourceRelative = 'assets\textures\desert\polyhaven\mud_cracked_dry_riverbed_002'
foreach ($desertDirectory in @('materials','tools\desert',$desertSourceRelative)) {
    New-Item -ItemType Directory -Path (Join-Path $desertRun $desertDirectory) -Force | Out-Null
}
$desertUtf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $desertRun 'project.godot'), "config_version=5`n[application]`nconfig/name=`"Bounded Clay Packing`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n", $desertUtf8)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build_clay_palette.gd') -Destination (Join-Path $desertRun 'build_clay_palette.gd')
$desertSourceDirectory = Join-Path $desertProject $desertSourceRelative
$desertProvenance = Get-Content -LiteralPath (Join-Path $desertSourceDirectory 'provenance.json') -Raw | ConvertFrom-Json
if ($desertProvenance.license -ne 'CC0-1.0' -or @($desertProvenance.maps).Count -ne 3) { throw 'Unexpected clay provenance.' }
foreach ($desertMap in $desertProvenance.maps) {
    $desertSourceFile = Join-Path $desertSourceDirectory $desertMap.file
    if ((Get-FileHash -LiteralPath $desertSourceFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $desertMap.sha256) { throw 'Clay source changed after download.' }
    Copy-Item -LiteralPath $desertSourceFile -Destination (Join-Path (Join-Path $desertRun $desertSourceRelative) $desertMap.file)
}
Copy-Item -LiteralPath (Join-Path $desertSourceDirectory 'provenance.json') -Destination (Join-Path (Join-Path $desertRun $desertSourceRelative) 'provenance.json')
$desertOriginalHashes = @{}
$desertOriginalFiles = @(Get-ChildItem -LiteralPath (Join-Path $desertProject 'materials') -File -Filter 'desert_*.res')
$desertOriginalFiles += Get-Item -LiteralPath (Join-Path $desertProject 'materials\desert_color_roughness.tres'),(Join-Path $desertProject 'materials\desert_normals.tres')
foreach ($desertOriginal in $desertOriginalFiles) {
    $desertOriginalHashes[$desertOriginal.Name] = (Get-FileHash -LiteralPath $desertOriginal.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Copy-Item -LiteralPath $desertOriginal.FullName -Destination (Join-Path $desertRun ('materials\' + $desertOriginal.Name))
}
$desertOriginalHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $desertRun 'original_sha256.json') -Encoding UTF8
$desertRecord = Invoke-OwnedGodot -Executable $GodotPath -Arguments ('--headless --audio-driver Dummy --path "' + $desertRun + '" --script res://build_clay_palette.gd') -WorkingDirectory $desertRun -LogPrefix (Join-Path $desertRun 'clay') -MinimumStartFree 768MB -MinimumRunningFree 384MB -WorkingSetCap 384MB -Seconds 180
$desertResult = Get-Content -LiteralPath (Join-Path $desertRun 'tools\desert\clay_palette_preparation.json') -Raw | ConvertFrom-Json
if ($desertResult.color_bytes -ne 5592432 -or $desertResult.normal_bytes -ne 1398128 -or -not $desertResult.mipmaps -or $desertResult.license -ne 'CC0-1.0') { throw 'Unexpected prepared clay output metadata.' }
foreach ($desertOriginalName in $desertOriginalHashes.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $desertProject ('materials\' + $desertOriginalName)) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $desertOriginalHashes[$desertOriginalName]) { throw 'Existing Desert resource changed during preparation; preserving current workspace.' }
}
foreach ($desertOutput in $desertOutputs) {
    if (Test-Path -LiteralPath (Join-Path $desertProject ('materials\' + $desertOutput))) { throw ('New material conflict; preserving: ' + $desertOutput) }
}
$desertPublished = @()
foreach ($desertOutput in $desertOutputs) {
    $desertPrepared = Join-Path $desertRun ('materials\' + $desertOutput)
    $desertDestination = Join-Path $desertProject ('materials\' + $desertOutput)
    [IO.File]::Copy($desertPrepared, $desertDestination, $false)
    $desertHash = (Get-FileHash -LiteralPath $desertPrepared -Algorithm SHA256).Hash.ToLowerInvariant()
    if ((Get-FileHash -LiteralPath $desertDestination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $desertHash) { throw 'Published clay resource readback mismatch.' }
    $desertPublished += @{path=('materials/' + $desertOutput);sha256=$desertHash;readback_verified=$true}
}
[ordered]@{state='prepared_published_not_rendered';run_directory=$desertRun;outputs=$desertPublished;source_provenance=($desertSourceRelative.Replace('\','/') + '/provenance.json');original_resource_hashes=$desertOriginalHashes;preparation=$desertResult;supervision=$desertRecord} | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'clay_palette_delivery.json') -Encoding UTF8
Write-Output ('Clay palette prepared and published without replacing original resources: ' + $desertRun)
