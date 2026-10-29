param([switch]$Review,[switch]$Benchmark,[switch]$Smoke)
$ErrorActionPreference='Stop'
& "$PSScriptRoot\run_test.ps1" -Script check_invariants
& "$PSScriptRoot\run_test.ps1" -Script check_geology
& "$PSScriptRoot\run_test.ps1" -Script check_regional_hills
& "$PSScriptRoot\run_test.ps1" -Script check_segment_index
& "$PSScriptRoot\run_test.ps1" -Script check_catchment_support
& "$PSScriptRoot\run_test.ps1" -Script check_hoodoos
& "$PSScriptRoot\run_test.ps1" -Script check_palette
& "$PSScriptRoot\run_test.ps1" -Script check_clay_gullies
& "$PSScriptRoot\run_test.ps1" -Script check_incised_profiles
& "$PSScriptRoot\run_test.ps1" -Script check_detail_selection
& "$PSScriptRoot\run_test.ps1" -Script check_compact_seams
& "$PSScriptRoot\run_test.ps1" -Script check_normal_interleave
& "$PSScriptRoot\run_test.ps1" -Script check_collision_precision
& "$PSScriptRoot\run_test.ps1" -Script check_native_landmarks
& "$PSScriptRoot\..\biome_extensions\run_test.ps1" -Script settings_ownership -ScriptFile res://tools/check_settings_ownership.gd
& "$PSScriptRoot\run_test.ps1" -Script check_assets
if($Review){
 & "$PSScriptRoot\run_test.ps1" -Script check_material_roles -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_color_space -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_color_space -GPU -Extra '--rendering-method forward_plus'
 & "$PSScriptRoot\run_test.ps1" -Script check_geology_gpu -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_geology_gpu -GPU -Extra '-- scaled'
 & "$PSScriptRoot\run_test.ps1" -Script check_palette_gpu -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_gpu_channels -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_texture_precision -GPU
 & "$PSScriptRoot\run_test.ps1" -Script check_normal_visibility -GPU
 & "$PSScriptRoot\run_test.ps1" -Script render_review -GPU -TimeoutSeconds 3600
 & "$PSScriptRoot\run_test.ps1" -Script check_review
}
if($Benchmark){
 & "$PSScriptRoot\run_test.ps1" -Script benchmark -GPU -Extra '-- mode=badlands'
 & "$PSScriptRoot\run_test.ps1" -Script benchmark -GPU -Extra '-- mode=grass'
 & "$PSScriptRoot\run_test.ps1" -Script profile_cpu
}
if($Smoke){& "$PSScriptRoot\smoke_launch.ps1"}
Write-Output 'Badlands requested checks finished; no export, commit or push.'
