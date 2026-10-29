param([string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ids = @('Ground092A','Ground054','Gravel020','Rock061','Ground031','Ground033')
function Text-Sha([string]$Text) {
 $h = [Security.Cryptography.SHA256]::Create()
 try { return [BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLower() } finally { $h.Dispose() }
}
$helperPath = Join-Path $PSScriptRoot 'owned_process.ps1'; $packPath = Join-Path $PSScriptRoot 'pack_source.gd'
if ((Text-Sha ([IO.File]::ReadAllText($helperPath))) -ne '6d1734c2c5368fa932eec46e594590bf4eb362809d305a1dd03cc3d70e79d75a') { throw 'Process helper changed; review before running.' }
if ((Text-Sha ([IO.File]::ReadAllText($packPath))) -ne 'bf598314de95c96c41806ede927fd5c3beda3eb1d1f6180aecd88433ca1bb4f7') { throw 'Packing source changed; review before running.' }
. $helperPath
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Recorded Godot executable missing.' }
if ([long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024 -lt 768MB) { throw 'Packing needs at least 768 MiB free RAM.' }
$materials = Join-Path $project 'materials'
$targets = @('desert_color_roughness.tres','desert_normals.tres')
foreach ($id in $ids) { $targets += 'desert_color_' + $id + '.res'; $targets += 'desert_normal_' + $id + '.res' }
foreach ($name in $targets) { if (Test-Path -LiteralPath (Join-Path $materials $name)) { throw ('Preserving existing material: ' + $name) } }
$artifacts = Join-Path $PSScriptRoot 'artifacts'
$run = Join-Path $artifacts ('bounded_pbr_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path (Join-Path $run 'output') | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $run 'project.godot'), "config_version=5`n[application]`nconfig/name=`"Bounded Desert Asset Packing`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n", $utf8)
[IO.File]::WriteAllText((Join-Path $run 'pack_source.gd'), [IO.File]::ReadAllText($packPath), $utf8)
$expectedArchives = @{
    'Ground092A' = '4238105a21a6698ad7b6b0f88c14453a437e863f4088fe6952351fbe317fe9d5'
    'Ground054' = '643e7c8689bac041f17c660eff6a5459bfe0535d4466737beb0e64902b23235a'
    'Gravel020' = 'ec96a0688696aa127a5c2226d057f4a31e4dd0186f359f53cfa694ae2e49526b'
    'Rock061' = '34d15ee39ed72be031adf88d6218e4ddbaf2e6560116ccb3a928e3b64a2228c3'
    'Ground031' = 'f6f0895ee706eb5e88a2f7bcaeb8f2b240d9bcd09b9d218a976de928f513f115'
    'Ground033' = 'a89f7c7940cae49435eaa582c37fd754f28096ce240d5f24001f74c6b652f023'
}
$sources = [object[]](ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $project 'assets\textures\desert\downloaded_manifest.json'))))
if ($sources.Count -ne 6) { throw 'Expected six source records.' }
$seen = @{}; Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($source in $sources) {
 if ($source.id -notin $ids -or $seen.ContainsKey($source.id)) { throw 'Unexpected or duplicate asset ID.' }; $seen[$source.id] = $true
 $archivePath = Join-Path $artifacts ('downloads\' + $source.id + '_2K-JPG.zip')
 if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLower() -ne $expectedArchives[$source.id]) { throw 'Original archive hash mismatch.' }
 if (@($source.maps).Count -ne 3) { throw 'Expected three source maps.' }
 $archive = [IO.Compression.ZipFile]::OpenRead($archivePath); $types = @{}
 try {
  foreach ($map in $source.maps) {
   if ($map.file -notmatch ('^' + [Regex]::Escape($source.id) + '_2K-JPG_(Color|NormalGL|Roughness)\.jpg$')) { throw 'Unexpected source map name.' }
   $type = $Matches[1]; if ($types.ContainsKey($type)) { throw 'Duplicate source map type.' }; $types[$type] = $true
   $file = Join-Path $project ('assets\textures\desert\' + $source.id + '\' + $map.file)
   if ((Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower() -ne $map.sha256) { throw 'Downloaded map changed; preserving it.' }
   $entry = $archive.GetEntry($map.file); if ($null -eq $entry) { throw 'Original archive entry missing.' }
   $stream = $entry.Open(); $hash = [Security.Cryptography.SHA256]::Create()
   try { $digest = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLower() } finally { $stream.Dispose(); $hash.Dispose() }
   if ($digest -ne $map.sha256) { throw 'Map differs from exact original archive entry.' }
  }
 } finally { $archive.Dispose() }
}
$results = @(); $supervision = @()
foreach ($id in $ids) {
 $arguments = '--headless --quit-after 2 --audio-driver Dummy --path "' + $run + '" --script res://pack_source.gd -- "' + $project + '" ' + $id
 $supervision += Invoke-OwnedGodot -Executable $GodotPath -Arguments $arguments -WorkingDirectory $run -LogPrefix (Join-Path $run $id) -MinimumStartFree 768MB -MinimumRunningFree 384MB -WorkingSetCap 384MB -Seconds 180
 $result = Get-Content -LiteralPath (Join-Path $run ('output\' + $id + '\result.json')) -Raw | ConvertFrom-Json
 if ($result.id -ne $id -or $result.color_bytes -ne 5592432 -or $result.normal_bytes -ne 1398128 -or -not $result.mipmaps) { throw 'Unexpected packed output metadata.' }
 $results += $result; Write-Output ('Packed and checked: ' + $id)
}
# Publish only after all six separate child runs succeed; refuse every conflict again.
foreach ($name in $targets) { if (Test-Path -LiteralPath (Join-Path $materials $name)) { throw ('New material conflict; preserving: ' + $name) } }
$published = @()
foreach ($id in $ids) {
 foreach ($kind in @('color','normal')) {
  $source = Join-Path $run ('output\' + $id + '\' + $kind + '.res'); $target = Join-Path $materials ('desert_' + $kind + '_' + $id + '.res')
  [IO.File]::Copy($source,$target,$false)
  $published += @{ file = $target; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLower() }
 }
}
foreach ($kind in @('color','normal')) {
 $name = if ($kind -eq 'color') { 'desert_color_roughness.tres' } else { 'desert_normals.tres' }
 $text = "[gd_resource type=`"Texture2DArray`" load_steps=7 format=3]`n`n"; $refs = @()
 for ($i=0; $i -lt $ids.Count; $i++) {
  $text += '[ext_resource type="Image" path="res://materials/desert_' + $kind + '_' + $ids[$i] + '.res" id="' + ($i+1) + '"]' + "`n"
  $refs += 'ExtResource("' + ($i+1) + '")'
 }
 $text += "`n[resource]`n_images = Array[Image]([" + ($refs -join ', ') + "])`n"
 $target = Join-Path $materials $name; $stream = [IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
 try { $bytes = $utf8.GetBytes($text); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
 $published += @{ file = $target; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLower() }
}
@{ completed = $true; run_directory = $run; results = $results; supervision = $supervision; published = $published; note = 'Source previews, arrays and real rendered material appearance still require inspection. No full-project import or GPU work performed.' } | ConvertTo-Json -Depth 9 | Set-Content -Encoding UTF8 (Join-Path $run 'packing_report.json')
Write-Output ('PBR packing completed: ' + $run)
