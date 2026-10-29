$ErrorActionPreference='Stop'
# Capture batches may overlap; never use this driver for performance benchmarks.
# Each engine has its own viewport/log/report and disjoint image names.
$rcProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rcPowerShell=(Get-Process -Id $PID).Path
$rcCases=@(
 @{id=1;features='boulder_shingle,broad_platform,coastal_plateau,coastal_ravines,connected_pools,dark_rocky_coast,fjord_inlets,forest_coast_transition'},
 @{id=2;features='granite_highlands,grass_coast_transition,headlands,isolated_stack,jungle_coast_transition,low_islands,mountain_coast_transition,offshore_group'},
 @{id=3;features='river_mouth,rocky_estuary,rocky_islets,rugged_shore,savanna_coast_transition,sea_stacks,sedimentary_cliffs,sheltered_coves'},
 @{id=4;features='sheltered_inlets,submerged_platform,swamp_coast_transition,tide_pools,towering_cliffs,underwater_cliff,wave_battered,wave_cut_platforms'}
)
for($rcWave=0;$rcWave -lt 2;$rcWave++){
 $rcChildren=@()
 foreach($rcCase in $rcCases[($rcWave*2)..($rcWave*2+1)]){
  $rcPrefix=Join-Path $rcProject ('.godot\rocky_coast_review_launcher_'+$rcCase.id)
  $rcArguments='-NoProfile -NonInteractive -File "'+$PSScriptRoot+'\run_test.ps1" -Script render_review -GPU -Extra "-- batch='+$rcCase.id+' feature='+$rcCase.features+'"'
  $rcChild=Start-Process -FilePath $rcPowerShell -ArgumentList $rcArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($rcPrefix+'.out.log') -RedirectStandardError ($rcPrefix+'.err.log')
  $null=$rcChild.Handle;$rcChildren+=@{process=$rcChild;id=$rcCase.id;prefix=$rcPrefix}
 }
 foreach($rcItem in $rcChildren){
  $rcItem.process.WaitForExit();$rcItem.process.Refresh()
  if($rcItem.process.ExitCode -ne 0){throw ('Coast review batch failed: '+$rcItem.id+'; see '+$rcItem.prefix)}
  Write-Output ('PASS native Coast visual batch '+$rcItem.id)
 }
}
& "$PSScriptRoot\run_test.ps1" -Script check_review
