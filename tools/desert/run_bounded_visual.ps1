param([string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe')
$ErrorActionPreference = 'Stop'
Write-Warning 'Historical broad fixture uses legacy lighting that previously clipped. Do not treat its color output as accepted; prefer manual game review and the tiny optical calibration. This script is not run automatically.'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$utf8 = New-Object Text.UTF8Encoding($false)
function Text-Sha([string]$Text) {
 $h = [Security.Cryptography.SHA256]::Create()
 try { return [BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLower() } finally { $h.Dispose() }
}
# Source text and native packed bytes are immutable inputs. Abort on any later user edit.
$textPins = @{
 'tools/desert/baseline/desert_material_before_wind.gdshaderinc' = '1f573f585dd7420197274cbee7a886c25f35cb0e374220a8fff8766fbe39824c'
 'shaders/desert_control_decode.gdshaderinc' = '47be43e7a3aa524123eb729aaab7bae673e01e1689e8cbdb400e6904c5009d84'
 'scripts/desert_settings.gd' = '751d0a8c732fb1ea05fede555839badec3942d7e8532f293e82396667a4127ca'
 'scripts/desert_sampler.gd' = '9e73437be2906d2a145d306a6eb7097af19070a4deb0333bbaeb2dc54258e0e4'
 'scripts/desert_drainage.gd' = '5704b71d6b4b9a9c943ac5ae6daf9df9653c199e93b637a4b1f8761b7c6798f3'
 'scripts/terrain_settings.gd' = '553a0b0d8c65b8cd894b440cfdbf2996235d2a27f0fa06e3c13672dae74f409f'
 'scripts/terrain_mesh_builder.gd' = '6fdf6373b5d6001c84ca31b7a5f7c41d8c3913fedcc3d1e15432a2cf6f4e111c'
 'shaders/terrain_biomes.gdshader' = '91c23857a622cce8f6c47fdf9a760dcbad6149f769c171d9bcb37aed2619b216'
 'shaders/desert_material.gdshaderinc' = 'd759fae6618b81dad44b3c6128cfca93029d374aea9ee9dee7e71a89aeacc244'
 'config/biomes/desert_settings.tres' = '5dda030afc2e8bc843e8d1fcce9849409795ddff61785f24c501d12da45fa66e'
 'tools/desert/preview_locations.json' = 'c652645cbd285ed1100c8f76a9b289016f893e5fc5db06dcd032e0ff173280a6'
 'config/world/terrain_settings.tres' = '94841c6b60f526364ff5d2f5c26c03ba397de095fe74937cea8c0268020e2a03'
 'tools/desert/render_material_review.gd' = 'f8662dd01f1ebbe821aacabb7e85694dc8c4d60dd8f4a3ca3aa06c984893630f'
 'tools/desert/desert_material_wind.gdshaderinc' = 'd759fae6618b81dad44b3c6128cfca93029d374aea9ee9dee7e71a89aeacc244'
 'tools/desert/owned_process.ps1' = '6d1734c2c5368fa932eec46e594590bf4eb362809d305a1dd03cc3d70e79d75a'
}
$binaryPins = @{
 'materials/desert_color_Ground092A.res' = '214bfb6bf50813d50252979fd1f72978337d22e88e720d5a6392c153bc47a8e0'
 'materials/desert_normal_Ground092A.res' = '812fb55c83169bda482b8505613db36a2fe82d4acb00843ffa219ce87a307a69'
 'materials/desert_color_Ground054.res' = 'e43bf1898f27e00a330eb6db6680c6762add42a11806e9d7e16a290c171b5a97'
 'materials/desert_normal_Ground054.res' = '4d50a8c1372805359b39ee28f64e1e525d2ff7cd470778040a17aa79a86505a5'
 'materials/desert_color_Gravel020.res' = '2388d4388aae0a52bff46b7ad5179c226f7694074ed2e648ffbc554ff90f29ea'
 'materials/desert_normal_Gravel020.res' = 'a8cdeb5b5c9f4d6fa94a08cb7a3e4f35fe2d3f647894ea7a0bd6da485a415036'
 'materials/desert_color_Rock061.res' = '4a5af237b49c742656119bc9db0ae419aace05d6ec6a0d6dc3e4fb67b9e400ae'
 'materials/desert_normal_Rock061.res' = 'c2676e522104d25a5275ceb5d704b0760e1e43af8ba9c2a53b3737688c3262fe'
 'materials/desert_color_Ground031.res' = '6e8f0a948085c12665fc9e305cb8da2fb8eac038fd45308444ec9e3475d863f0'
 'materials/desert_normal_Ground031.res' = '073e7ef19c5ffcf9f298464026b7dee400a7566598168ee0b7dea5a4a71a29b9'
 'materials/desert_color_Ground033.res' = 'f708a3668a92dfda0241fb7a3d32ca4736b06c5ac21c75600acc7d6fc2e209ac'
 'materials/desert_normal_Ground033.res' = '3774067e60aa6a0afc941c907d4dd3b17b0506c8e9e21b1b7595d7a5e6afe46d'
 'materials/desert_color_roughness.tres' = '5842a88a5e4248df4f824c4574bde6ffe0262ba7093fa3006b8975d71868d210'
 'materials/desert_normals.tres' = 'ec599c655b7697574cb10f0090ee7612abd80da0c3e94b7b1155ba937fa33f42'
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Recorded Godot executable missing.' }
if ([long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024 -lt 1GB) { throw 'Visual fixture needs at least 1 GiB free RAM.' }
$sourceTexts = @{}
foreach ($relative in $textPins.Keys) {
 $text = [IO.File]::ReadAllText((Join-Path $project $relative))
 if ((Text-Sha $text) -ne $textPins[$relative]) { throw ('Preserving changed source: ' + $relative) }
 $sourceTexts[$relative] = $text
}
foreach ($relative in $binaryPins.Keys) {
 if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $project $relative)).Hash.ToLower() -ne $binaryPins[$relative]) { throw ('Preserving changed packed resource: ' + $relative) }
}
. (Join-Path $PSScriptRoot 'owned_process.ps1')
$run = Join-Path (Join-Path $PSScriptRoot 'artifacts') ('bounded_visual_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run | Out-Null
foreach ($name in @('scripts','shaders','materials','captures')) { New-Item -ItemType Directory -Path (Join-Path $run $name) | Out-Null }
function Write-NewText([string]$Relative,[string]$Text) {
 $file = Join-Path $run $Relative
 $stream = [IO.File]::Open($file,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
 try { $bytes = $utf8.GetBytes($Text); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
# Isolated local preloads replace editor global-class cache only in copied scripts.
foreach ($relative in $textPins.Keys) {
 if (-not $relative.StartsWith('scripts/')) { continue }
 $text = $sourceTexts[$relative]
 $text = $text.Replace("class_name DesertSettings`n",'').Replace("class_name TerrainSettings`n",'')
 if ($relative -in @('scripts/desert_sampler.gd','scripts/desert_drainage.gd','scripts/terrain_settings.gd','scripts/terrain_mesh_builder.gd')) {
  $text = $text.Replace("extends RefCounted`n","extends RefCounted`nconst DesertSettings = preload(`"res://scripts/desert_settings.gd`")`n").Replace("extends Resource`n","extends Resource`nconst DesertSettings = preload(`"res://scripts/desert_settings.gd`")`n")
 }
 if ($relative -eq 'scripts/terrain_mesh_builder.gd') { $text = $text.Replace("extends RefCounted`n","extends RefCounted`nconst TerrainSettings = preload(`"res://scripts/terrain_settings.gd`")`n") }
 Write-NewText $relative $text
}
foreach ($relative in $binaryPins.Keys) { [IO.File]::Copy((Join-Path $project $relative),(Join-Path $run $relative),$false) }
Write-NewText 'config/world/terrain_settings.tres' $sourceTexts['config/world/terrain_settings.tres']
Write-NewText 'config/biomes/desert_settings.tres' $sourceTexts['config/biomes/desert_settings.tres']
Write-NewText 'preview_locations.json' $sourceTexts['tools/desert/preview_locations.json']
Write-NewText 'render_material_review.gd' $sourceTexts['tools/desert/render_material_review.gd']
Write-NewText 'shaders/desert_control_decode.gdshaderinc' $sourceTexts['shaders/desert_control_decode.gdshaderinc']
Write-NewText 'shaders/terrain_biomes.gdshader' $sourceTexts['shaders/terrain_biomes.gdshader']
Write-NewText 'shaders/terrain_baseline.gdshader' ($sourceTexts['shaders/terrain_biomes.gdshader'].Replace('res://shaders/desert_material.gdshaderinc','res://shaders/desert_material_baseline.gdshaderinc'))
Write-NewText 'shaders/desert_material.gdshaderinc' $sourceTexts['tools/desert/desert_material_wind.gdshaderinc']
Write-NewText 'shaders/desert_material_baseline.gdshaderinc' $sourceTexts['tools/desert/baseline/desert_material_before_wind.gdshaderinc']
$projectText = @'
config_version=5
[application]
config/name="Bounded Desert material review"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/mode=0
[rendering]
renderer/rendering_method="gl_compatibility"
textures/default_filters/anisotropic_filtering_level=4
'@
Write-NewText 'project.godot' $projectText
@{ text_pins = $textPins; binary_pins = $binaryPins; original_project = $project; isolated_fixture = $run; runtime_sources_unchanged = $true } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $run 'input_manifest.json')
$arguments = '--rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1280x720 --audio-driver Dummy --path "' + $run + '" --script res://render_material_review.gd -- require-render'
$allResults = @(Invoke-OwnedGodot -Executable $GodotPath -Arguments $arguments -WorkingDirectory $run -LogPrefix (Join-Path $run 'visual') -MinimumStartFree 1GB -MinimumRunningFree 512MB -WorkingSetCap 512MB -Seconds 420)
# PowerShell 5 emits empty VoidTaskResult objects from helper awaiters. Select the actual record explicitly.
$supervision = @($allResults | Where-Object { $_ -is [System.Collections.IDictionary] -and $_.ContainsKey('exit_code') })
if ($supervision.Count -ne 1 -or $supervision[0].exit_code -ne 0) { throw 'Expected one successful supervised visual child.' }
foreach ($logName in @('visual.stdout.log','visual.stderr.log')) {
 if ([IO.File]::ReadAllText((Join-Path $run $logName)) -match 'SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed|ERROR:') { throw ('Renderer logged an error: ' + $logName) }
}
$report = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $run 'visual_report.json')))
if ($report.headless -or $report.renderer -ne 'gl_compatibility' -or [string]::IsNullOrWhiteSpace($report.adapter) -or $report.rendered_frames -lt 51) { throw 'Actual GPU renderer/frame evidence missing.' }
if ($report.viewport -ne '(1280, 720)' -or @($report.captures).Count -ne 51 -or @($report.feature_checks).Count -ne 12) { throw 'Unexpected capture dimensions or feature count.' }
$pngs = @(); $seen = @{}
foreach ($capture in $report.captures) {
 if (-not $capture.rendered -or $capture.name -notmatch '^[a-z_]+$' -or $seen.ContainsKey($capture.name)) { throw 'Invalid or duplicate capture record.' }
 $seen[$capture.name] = $true; $file = Join-Path $run ('captures\' + $capture.name + '.png')
 if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -lt 1024) { throw 'Missing or invalid rendered image.' }
 $pngs += @{ name = $capture.name; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower(); bytes = (Get-Item -LiteralPath $file).Length }
}
@{ completed = $true; run_directory = $run; supervision = $supervision[0]; captures = $pngs; note = 'Images require human visual review. Isolated pure Desert only, no full-world streaming, Grass transition or oasis water acceptance. Wind shader candidate remains unapplied to runtime.' } | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $run 'visual_completion.json')
Write-Output ('Bounded real GL captures completed: ' + $run)
