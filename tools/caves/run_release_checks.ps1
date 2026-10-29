$ErrorActionPreference='Stop'
$releaseRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$releaseRunner=Join-Path $releaseRoot 'tools/biome_extensions/run_test.ps1'
$releaseTests=@('check_surface_cut','check_backend_stationary','check_magma_registration','check_magma_foundation','check_magma_heat_source','check_magma_thermal_field','check_magma_cooled','check_magma_tubes','check_magma_deposits','check_magma_provinces','check_magma_lake_adoption','check_magma_lava_drip_adoption','check_magma_cascades','check_magma_controls','check_large_magma_field_bounds','check_zero_depth_exclusion','check_fluid_material_binding')
$releaseRows=[Collections.Generic.List[object]]::new()
foreach($releaseName in $releaseTests){
 $releaseFailure=''
 try {& $releaseRunner -Script ('release_'+$releaseName) -ScriptFile ('res://tools/caves/'+$releaseName+'.gd') -MemoryLimitMiB 2048} catch {$releaseFailure=$_.Exception.Message}
 $releaseRows.Add([ordered]@{name=$releaseName;passed=($releaseFailure -eq '');failure=$releaseFailure})
}
$releaseReport=[ordered]@{passed=(@($releaseRows | Where-Object {-not $_.passed}).Count -eq 0);completed_utc=[DateTime]::UtcNow.ToString('o');tests=$releaseRows;scope='Sequential current numeric/native headless cave release checks. Per-engine2048MiB bound;GPU/physical live return and startup are separate reports.'}
[IO.File]::WriteAllText((Join-Path $releaseRoot 'tools/biome_extensions/artifacts/cave_release_checks.json'),($releaseReport | ConvertTo-Json -Depth 8))
if(-not $releaseReport.passed){throw 'Cave release checks contain failures;see retained report'}
