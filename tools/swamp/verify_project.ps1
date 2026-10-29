param([switch]$Review,[switch]$Normal,[switch]$Flood,[switch]$Benchmark,[switch]$Smoke,[string]$Feature="")
$ErrorActionPreference="Stop"
& "$PSScriptRoot\run_test.ps1" -Script check_invariants
& "$PSScriptRoot\run_test.ps1" -Script check_materials
& "$PSScriptRoot\run_test.ps1" -Script check_gpu_channels -GPU
& "$PSScriptRoot\run_test.ps1" -Script check_texture_precision -GPU
if($Review){& "$PSScriptRoot\run_test.ps1" -Script render_review -GPU -Extra $(if($Feature){"-- feature="+$Feature}else{""})}
if($Normal){& "$PSScriptRoot\run_test.ps1" -Script check_normal_visibility -GPU}
if($Flood){& "$PSScriptRoot\run_test.ps1" -Script check_flood_stage -GPU}
if($Benchmark){foreach($swMode in @("baseline","grass","swamp")){if($swMode -eq "baseline" -and -not (Test-Path -LiteralPath "$PSScriptRoot\baseline\builder.gd")){Write-Warning "Local baseline fixture unavailable; baseline comparison skipped.";continue};& "$PSScriptRoot\run_test.ps1" -Script benchmark -GPU -Extra ("-- mode="+$swMode)}}
if($Smoke){& "$PSScriptRoot\smoke_launch.ps1"}
Write-Output "Swamp verification finished. No export performed."
