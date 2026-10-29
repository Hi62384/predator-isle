param(
    [ValidateSet('core','canonical','import','shader_assets','invariants','slopes','profile','grass','drainage','crossings','discovery','optimization')][string]$Stage = 'core',
    [string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe'
)
# One explicitly selected sequential stage, only in the parent's heavy slot.
# Preserves full-project 3 GiB entry guard and the existing bounded-core limits.
$ErrorActionPreference = 'Stop'
$desertProject = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$desertFree = [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1024
$desertRequired = if ($Stage -in @('core','canonical')) { 512MB } else { 3GB }
if ($desertFree -lt $desertRequired) {
    Write-Output "Stage $Stage blocked: free RAM $desertFree bytes; requires $desertRequired bytes."
    exit 42
}
. (Join-Path $PSScriptRoot 'owned_process.ps1')
$desertRun = Join-Path $PSScriptRoot ('artifacts\current_' + $Stage + '_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $desertRun | Out-Null
$desertUtf8 = New-Object Text.UTF8Encoding($false)
$desertHashes = @{}
foreach ($desertSource in @('scripts/desert_settings.gd','scripts/desert_sampler.gd','scripts/desert_drainage.gd','scripts/terrain_mesh_builder.gd','scripts/chunk_terrain.gd','scripts/free_camera.gd','shaders/desert_material.gdshaderinc','shaders/terrain_biomes.gdshader','shaders/desert_control_decode.gdshaderinc','config/world/terrain_settings.tres','config/biomes/desert_settings.tres','tools/desert/run_current_verification.ps1','tools/desert/profile_current_desert.gd','tools/desert/check_saved_preset.gd','tools/desert/check_shader_assets.gd','tools/desert/check_desert.gd','tools/desert/check_sprint_optimization.gd','tools/desert/sprint_baseline_20261014/desert_sampler.gd')) {
    $desertHashes[$desertSource] = (Get-FileHash -LiteralPath (Join-Path $desertProject $desertSource) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$desertHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $desertRun 'source_sha256.json') -Encoding UTF8
if ($Stage -in @('core','canonical')) {
    New-Item -ItemType Directory -Path (Join-Path $desertRun 'scripts') | Out-Null
    foreach ($desertName in @('desert_settings.gd','desert_sampler.gd','desert_drainage.gd')) {
        $desertText = [IO.File]::ReadAllText((Join-Path $desertProject ('scripts\' + $desertName)))
        if ($desertName -eq 'desert_settings.gd') {
            $desertText = [regex]::Replace($desertText, '(?m)^class_name DesertSettings\r?\n', '')
        } else {
            $desertText = [regex]::Replace($desertText, '^extends RefCounted\r?\n', "extends RefCounted`nconst DesertSettings = preload(`"res://scripts/desert_settings.gd`")`n")
        }
        [IO.File]::WriteAllText((Join-Path $desertRun ('scripts\' + $desertName)), $desertText, $desertUtf8)
    }
    $desertHarness = 'native_core_check.gd'
    if ($Stage -eq 'canonical') {
        $desertHarness = 'check_canonical_neighbors.gd'
        $desertSettingsText = [IO.File]::ReadAllText((Join-Path $desertProject 'scripts\terrain_settings.gd'))
        $desertSettingsText = [regex]::Replace($desertSettingsText, '(?m)^class_name TerrainSettings\r?\n', 'const DesertSettings = preload("res://scripts/desert_settings.gd")' + "`n")
        [IO.File]::WriteAllText((Join-Path $desertRun 'scripts\terrain_settings.gd'), $desertSettingsText, $desertUtf8)
        Copy-Item -LiteralPath (Join-Path $desertProject 'config/world/terrain_settings.tres'),(Join-Path $desertProject 'config/biomes/desert_settings.tres') -Destination $desertRun
        New-Item -ItemType Directory -Path (Join-Path $desertRun 'tools\desert\baseline') | Out-Null
        foreach ($desertBuilderPath in @('scripts/terrain_mesh_builder.gd','tools/desert/baseline/builder.gd')) {
            $desertBuilderText = [IO.File]::ReadAllText((Join-Path $desertProject $desertBuilderPath))
            $desertBuilderText = [regex]::Replace($desertBuilderText, '^extends RefCounted\r?\n', "extends RefCounted`nconst TerrainSettings = preload(`"res://scripts/terrain_settings.gd`")`nconst DesertSettings = preload(`"res://scripts/desert_settings.gd`")`n")
            [IO.File]::WriteAllText((Join-Path $desertRun $desertBuilderPath), $desertBuilderText, $desertUtf8)
        }
        foreach ($desertInput in @('scripts/terrain_settings.gd','config/world/terrain_settings.tres','config/biomes/desert_settings.tres','tools/desert/baseline/builder.gd','tools/desert/check_canonical_neighbors.gd')) {
            $desertHashes[$desertInput] = (Get-FileHash -LiteralPath (Join-Path $desertProject $desertInput) -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $desertHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $desertRun 'source_sha256.json') -Encoding UTF8
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $desertHarness) -Destination (Join-Path $desertRun $desertHarness)
    [IO.File]::WriteAllText((Join-Path $desertRun 'project.godot'), "config_version=5`n[application]`nconfig/name=`"Current Desert Core`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n", $desertUtf8)
    $desertRecord = Invoke-OwnedGodot -Executable $GodotPath -Arguments ('--headless --audio-driver Dummy --path "' + $desertRun + '" --script res://' + $desertHarness) -WorkingDirectory $desertRun -LogPrefix (Join-Path $desertRun $Stage) -MinimumStartFree 512MB -MinimumRunningFree 384MB -WorkingSetCap 256MB -Seconds 120
    $desertResultName = if ($Stage -eq 'core') { 'tools/diagnostics/artifacts/native_core_results.json' } else { 'tools/diagnostics/artifacts/canonical_neighbors.json' }
    $desertResults = Get-Content -LiteralPath (Join-Path $desertRun $desertResultName) -Raw | ConvertFrom-Json
    if (@($desertResults.failures).Count -ne 0) { throw 'Current canonical/core checks failed.' }
    if ($Stage -eq 'core' -and $desertResults.comparisons -ne 1839) { throw 'Core comparison count changed.' }
    if ($Stage -eq 'canonical' -and ($desertResults.shared_coordinates -ne 2304 -or $desertResults.grass_neighbors -le 100)) { throw 'Canonical comparison coverage changed.' }
} else {
    $desertArgs = switch ($Stage) {
        'import' { '--editor --quit' }
        'shader_assets' { '--script res://tools/desert/check_shader_assets.gd' }
        'invariants' { '--script res://tools/desert/check_desert.gd' }
        'slopes' { '--script res://tools/desert/audit_dune_slopes.gd' }
        'profile' { '--script res://tools/desert/profile_current_desert.gd' }
        'optimization' { '--script res://tools/desert/check_sprint_optimization.gd' }
        'grass' { '--script res://tools/desert/check_saved_preset.gd' }
        'drainage' { '--script res://tools/desert/audit_drainage_beds.gd' }
        'crossings' { '--script res://tools/desert/audit_network_crossings.gd' }
        'discovery' { '--script res://tools/desert/find_previews.gd' }
    }
    $desertOutputs = @{
        shader_assets = 'current_shader_assets.json'
        invariants = 'cpu_checks_windows.json'
        profile = 'current_stage_profile.json'
        optimization = 'current_sprint_optimization.json'
        grass = 'current_saved_preset_grass.json'
        drainage = 'drainage_bed_audit.json'
        crossings = 'network_crossings.json'
        discovery = 'preview_locations.json'
    }
    # Retain existing evidence before a harness replaces its conventional report.
    $desertOutputPath = $null
    if ($desertOutputs.ContainsKey($Stage)) {
        $desertOutputPath = Join-Path $PSScriptRoot $desertOutputs[$Stage]
        if (Test-Path -LiteralPath $desertOutputPath -PathType Leaf) {
            Copy-Item -LiteralPath $desertOutputPath -Destination (Join-Path $desertRun ('previous_' + $desertOutputs[$Stage]))
        }
    }
    $desertStageStarted = [DateTime]::UtcNow
    $desertFreshReport = $false
    try {
        $desertRecord = Invoke-OwnedGodot -Executable $GodotPath -Arguments ('--headless --audio-driver Dummy --path "' + $desertProject + '" ' + $desertArgs) -WorkingDirectory $desertProject -LogPrefix (Join-Path $desertRun $Stage) -MinimumStartFree 3GB -MinimumRunningFree 768MB -WorkingSetCap 2GB -Seconds 240
    } finally {
        # Logs and failed reports are as important as successful runs.
        if ($null -ne $desertOutputPath -and (Test-Path -LiteralPath $desertOutputPath -PathType Leaf)) {
            $desertFreshReport = [IO.File]::GetLastWriteTimeUtc($desertOutputPath) -ge $desertStageStarted
            if ($desertFreshReport) {
                Copy-Item -LiteralPath $desertOutputPath -Destination (Join-Path $desertRun $desertOutputs[$Stage])
            }
        }
        @{ report_path = $desertOutputPath; written_this_run = $desertFreshReport; stage_started_utc = $desertStageStarted.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $desertRun 'report_status.json') -Encoding UTF8
    }
    if ($null -ne $desertOutputPath -and -not $desertFreshReport) { throw 'The stage did not write a fresh report; previous evidence is not a current result.' }
}
Write-Output ('Completed current-source ' + $Stage + ': ' + $desertRun)
$desertRecord | ConvertTo-Json -Depth 6
