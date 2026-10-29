param([switch]$ResumeAfterWalk,[switch]$ResumeAfterProfiles,[switch]$ReuseNativeProfiles,[switch]$ReuseCustomWalks,[ValidateSet('membrane_root')][string]$NativeProfilePrefix='membrane_root')
$ErrorActionPreference='Stop'
# Deliberately serial: performance evidence must not compete with another test.
$alienRunner=Join-Path $PSScriptRoot 'run_test.ps1'
$alienPrelude=@('check_production_network_tiles','check_network_tile_eviction','check_production_nerve_fibres','check_carapace_placement_policy','check_carapace_geometry','check_carapace_admission','check_carapace_collision','check_production_conduit_memo','check_conduit_footings','check_conduit_shoulders','check_alien_edge_cache','check_alien_junctions','check_junction_admission','check_membrane_clearance','check_membrane_candidate','check_membrane_junction_candidate','check_membrane_attachments','check_membrane_collision','check_production_membranes','check_junction_collision','check_scene_sun')
$alienGPU=@('check_debug_light_invariance','check_biological_projection','check_authored_color_space','check_normal_controls','check_structure_normal_controls','render_junctions','render_carapace','render_production_nerve_fibres')
$alienPrelude+=@('check_junction_custom_admission','check_surface_guide_candidate','check_surface_guide_attachments','check_surface_guide_topology','check_surface_guide_collision')
$alienPrelude+=@('check_far_conduit_lod','check_lod_controller','check_runtime_structure_lod')
$alienPrelude+=@('check_junction_navigation_admission','check_native_walk_admission','check_rejected_steep_approach')
$alienPrelude+=@('check_margin_retaining_lod','check_margin_lod_protected','check_margin_lod_controller','check_margin_lod_shore_sites','check_runtime_margin_lod')
$alienGPU+=@('render_margin_lod_shores')
$alienProfiles=@('profile_conduit_foundations','profile_junctions','profile_carapace','profile_production_conduit_memo','profile_production_network_tiles','profile_nerve_fibres','profile_membranes')
$alienProfiles+=@('profile_margin_retaining_lod')
function Assert-AlienReports([string[]]$Names){
 $alienRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
 foreach($alienTest in $Names){
  $alienReportName=if($alienTest -eq 'check_authored_color_space'){'check_authored_color_space_gl_compatibility'}else{$alienTest}
  $alienReport=Get-Content -LiteralPath (Join-Path $PSScriptRoot ('artifacts/'+$alienReportName+'.json')) -Raw | ConvertFrom-Json
  if(($alienReport.PSObject.Properties.Name -contains 'passed' -and -not $alienReport.passed) -or $alienReport.failures.Count -gt 0 -or $null -eq $alienReport.source_sha256){throw ('Failed/unguarded resume report '+$alienTest)}
  foreach($alienSource in $alienReport.source_sha256.PSObject.Properties){
   if(-not $alienSource.Name.StartsWith('res://')){throw 'Unexpected resume source prefix'}
   $alienSourcePath=[System.IO.Path]::GetFullPath((Join-Path $alienRoot $alienSource.Name.Substring(6)))
   if(-not $alienSourcePath.StartsWith($alienRoot+[System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)){throw 'Resume source outside workspace'}
   if((Get-FileHash -LiteralPath $alienSourcePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $alienSource.Value){throw ('Stale resume source '+$alienTest+': '+$alienSource.Name)}
  }
  if($alienTest -eq 'check_junction_walk' -and $alienReport.cases.Count -ne 3){throw 'All three current walk cases required'}
  if($alienTest -eq 'check_nerve_fibre_walk' -and (-not $alienReport.finished -or $alienReport.route_length_m -ne 480)){throw 'Completed actual fibre return route required'}
  Write-Output ('VERIFIED current resume evidence '+$alienTest)
 }
}
if($ResumeAfterWalk -or $ResumeAfterProfiles){
 Assert-AlienReports ($alienPrelude+@('check_junction_walk','check_nerve_fibre_walk'))
}else{
 foreach($alienTest in $alienPrelude){ & $alienRunner -Script $alienTest }
 & $alienRunner -Script check_junction_walk -Extra '--fixed-fps 60'
 & $alienRunner -Script check_nerve_fibre_walk -Extra '--fixed-fps 60'
}
if($ReuseCustomWalks){
 Assert-AlienReports @('check_junction_navigation_walk_diagnostic_scale_0p2','check_junction_navigation_walk_diagnostic_scale_2p0')
}else{
 foreach($alienScale in @('0.2','2')){ & $alienRunner -Script check_junction_navigation_walk -Extra ('--fixed-fps 60 -- scale='+$alienScale) -MemoryLimitMiB 2048 }
}
& $alienRunner -Script save_custom_junction_walks
if($ResumeAfterProfiles){
 Assert-AlienReports (@('profile_feature_ground_attachment')+$alienGPU+$alienProfiles)
}else{
 & $alienRunner -Script profile_feature_ground_attachment
 foreach($alienTest in $alienGPU){
  if($alienTest -eq 'render_margin_lod_shores'){ & $alienRunner -Script $alienTest -GPU -MemoryLimitMiB 2048 }
  else{ & $alienRunner -Script $alienTest -GPU }
 }
 foreach($alienTest in $alienProfiles){ & $alienRunner -Script $alienTest }
}
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'run_surface_regression.ps1')
if(-not $ReuseNativeProfiles){
 for($alienRepeat=0;$alienRepeat -lt 3;$alienRepeat++){
  $alienOrder=if($alienRepeat%2 -eq 0){@(0,8)}else{@(8,0)}
  foreach($alienBudget in $alienOrder){
   $alienLabel=$NativeProfilePrefix+'_'+$(if($alienBudget -eq 8){'on'}else{'off'})+'_'+$alienRepeat
   & $alienRunner -Script profile_streaming -GPU -Extra ('-- cache='+$alienBudget+' scenario=root label='+$alienLabel)
  }
 }
}
& $alienRunner -Script review_conduit_memo_streaming -Extra ('-- prefix='+$NativeProfilePrefix)
if(-not $ReuseNativeProfiles){
 for($alienRepeat=0;$alienRepeat -lt 3;$alienRepeat++){
  $alienOrder=if($alienRepeat%2 -eq 0){@(0,1)}else{@(1,0)}
  foreach($alienQuery in $alienOrder){
   $alienLabel='query_root_'+$(if($alienQuery -eq 1){'on'}else{'off'})+'_'+$alienRepeat
   & $alienRunner -Script profile_streaming -GPU -Extra ('-- cache=8 query='+$alienQuery+' scenario=root label='+$alienLabel)
  }
 }
}
& $alienRunner -Script review_conduit_memo_streaming -Extra '-- prefix=query_root study=query'
& $alienRunner -Script save_alien_attachment_report
& $alienRunner -Script preserve_alien_checkpoint
Write-Output 'ALIEN_CHECKPOINT_COMPLETE: scoped evidence only; full requested work remains unfinished.'
