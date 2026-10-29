param([switch]$Review,[switch]$Normal,[switch]$Benchmark,[switch]$Smoke)
$ErrorActionPreference='Stop'
foreach($beachCase in @('check_invariants','check_profiles','check_materials')){& "$PSScriptRoot/run_test.ps1" -Script $beachCase}
foreach($beachCase in @('check_gpu_channels','check_texture_precision')){& "$PSScriptRoot/run_test.ps1" -Script $beachCase -GPU}
if($Normal){& "$PSScriptRoot/run_test.ps1" -Script check_normal_visibility -GPU}
if($Review){& "$PSScriptRoot/review_all.ps1"; & "$PSScriptRoot/run_test.ps1" -Script check_review}
if($Benchmark){foreach($beachMode in @('grass','coast','beach')){& "$PSScriptRoot/run_test.ps1" -Script benchmark -GPU -Extra ('-- mode='+$beachMode)}}
if($Smoke){& "$PSScriptRoot/smoke_launch.ps1"}
Write-Output 'Beach verification finished. No export performed.'
