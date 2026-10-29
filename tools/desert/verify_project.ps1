param(
    [string]$GodotPath = 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe',
    [switch]$Render
)
# Project checks only. Never exports, downloads, rewrites Git, or edits presets.
$ErrorActionPreference = 'Stop'
$desertProject = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$desertLogs = Join-Path $desertProject '.godot\finish_verification'
New-Item -ItemType Directory -Force -Path $desertLogs | Out-Null
$desertCases = @(
    'tools/desert/native_core_check.gd',
    'tools/desert/check_canonical_neighbors.gd',
    'tools/desert/check_dune_culling.gd',
    'tools/desert/check_height_only.gd',
    'tools/desert/check_normal_sampling.gd',
    'tools/desert/check_drainage_culling.gd',
    'tools/desert/check_sparse_halo.gd',
    'tools/desert/check_far_mesh_budget.gd',
    'tools/desert/check_desert_edge_cases.gd',
    'tools/desert/check_desert.gd',
    'tools/desert/check_saved_preset.gd',
    'tools/check_cache_order.gd',
    'tools/check_hierarchical_mesh.gd',
    'tools/check_biome_coverage.gd',
    'tools/check_cliff_config_save.gd'
)
if ($Render) {
    $desertCases += @('tools/desert/check_shader_assets.gd','tools/desert/check_desert_gpu_channels.gd','tools/check_material_binding.gd','tools/check_cliff_config.gd','tools/check_streaming_reload.gd')
}
$desertRecords = @()
foreach ($desertCase in $desertCases) {
    $desertName = [IO.Path]::GetFileNameWithoutExtension($desertCase)
    $desertPrefix = Join-Path $desertLogs $desertName
    $desertGpu = $desertCase -in @('tools/desert/check_shader_assets.gd','tools/desert/check_desert_gpu_channels.gd','tools/check_material_binding.gd','tools/check_cliff_config.gd','tools/check_streaming_reload.gd')
    $desertArgs = '--path "' + $desertProject + '" --log-file "' + $desertPrefix + '.engine.log" '
    $desertArgs += if ($desertGpu) { '--windowed --resolution 1472x512 ' } else { '--headless ' }
    $desertArgs += '--script res://' + $desertCase
    $desertChild = Start-Process -FilePath $GodotPath -WorkingDirectory $desertProject -ArgumentList $desertArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($desertPrefix+'.out.log') -RedirectStandardError ($desertPrefix+'.err.log')
    $desertHandle = $desertChild.Handle
    $desertStarted = [DateTime]::UtcNow
    while (-not $desertChild.WaitForExit(500)) {
        $desertText = if (Test-Path -LiteralPath ($desertPrefix+'.engine.log')) { Get-Content -LiteralPath ($desertPrefix+'.engine.log') -Raw } else { '' }
        if ($desertText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$desertStarted).TotalSeconds -gt 130) {
            $desertChild.Kill(); $desertChild.WaitForExit()
            throw ('Failed/timed out: '+$desertCase+'; see '+$desertPrefix+'.engine.log')
        }
    }
    $desertChild.WaitForExit(); $desertChild.Refresh()
    $desertText = Get-Content -LiteralPath ($desertPrefix+'.engine.log') -Raw
    if ($desertChild.ExitCode -ne 0 -or $desertText -match 'SCRIPT ERROR|SHADER ERROR|Assertion failed|Parse Error') { throw ('Failed: '+$desertCase) }
    $desertRecords += @{script=$desertCase;rendered=$desertGpu;exit_code=$desertChild.ExitCode;elapsed_s=([DateTime]::UtcNow-$desertStarted).TotalSeconds;log=$desertPrefix+'.engine.log'}
    Write-Output ('PASS '+$desertCase)
}
$desertRecords | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'project_test_run.json') -Encoding UTF8
Write-Output ('PASS '+$desertRecords.Count+' project checks; no export performed')
