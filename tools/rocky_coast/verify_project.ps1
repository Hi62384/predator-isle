param([switch]$Review,[switch]$Normal,[switch]$Benchmark,[switch]$Smoke,[string]$Feature="")
$ErrorActionPreference="Stop"
& "$PSScriptRoot\run_test.ps1" -Script check_invariants
& "$PSScriptRoot\run_test.ps1" -Script check_materials
& "$PSScriptRoot\run_test.ps1" -Script check_lighting
& "$PSScriptRoot\run_test.ps1" -Script check_gpu_channels -GPU
& "$PSScriptRoot\run_test.ps1" -Script check_texture_precision -GPU
if($Review){if($Feature){& "$PSScriptRoot\run_test.ps1" -Script render_review -GPU -Extra ("-- feature="+$Feature)}else{& "$PSScriptRoot\review_all.ps1"}}
& "$PSScriptRoot\run_test.ps1" -Script check_ocean_foam -GPU
if($Normal){& "$PSScriptRoot\run_test.ps1" -Script check_normal_visibility -GPU}
if($Benchmark){foreach($mtMode in @("baseline","grass","coast")){& "$PSScriptRoot\run_test.ps1" -Script benchmark -GPU -Extra ("-- mode="+$mtMode)}}
if($Smoke){& "$PSScriptRoot\smoke_launch.ps1"}
Write-Output "Rocky Coast verification finished. No export performed."
