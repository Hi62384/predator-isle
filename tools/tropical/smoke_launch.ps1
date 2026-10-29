param([string]$Feature='')
$ErrorActionPreference='Stop'
$trProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$trGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$trModes=if($Feature){@($Feature)}else{@('mountain_belt','freshwater_lake','freshwater_pool','grass_tropical_transition','forest_tropical_transition','jungle_tropical_transition','savanna_tropical_transition','swamp_tropical_transition','mountain_tropical_transition','beach_tropical_transition','coast_tropical_transition','saved_world')}
foreach($trMode in $trModes){
 $trPrefix=Join-Path $trProject ('.godot\tropical_smoke_'+$trMode)
 $trArgs='--path "'+$trProject+'" --windowed --resolution 1280x720 --log-file "'+$trPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/tropical/artifacts/smoke_'+$trMode
 if($trMode -ne 'saved_world'){$trArgs+=' tropical-preview tropical-feature='+$trMode}
 $trChild=Start-Process -FilePath $trGodot -WorkingDirectory $trProject -ArgumentList $trArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($trPrefix+'.out.log') -RedirectStandardError ($trPrefix+'.err.log')
 $null=$trChild.Handle;$trStarted=[DateTime]::UtcNow
 while(-not $trChild.WaitForExit(500)){
  $trText=if(Test-Path -LiteralPath ($trPrefix+'.engine.log')){Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw}else{''}
  if($trText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$trStarted).TotalSeconds -gt 150){$trChild.Kill();$trChild.WaitForExit();throw ('Smoke failed/timed out: '+$trMode)}
 }
 $trChild.WaitForExit();$trChild.Refresh();$trText=Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw
 if($trChild.ExitCode -ne 0 -or $trText -notmatch 'RUNTIME_SMOKE_PASS' -or $trText -match 'ERROR:'){throw ('Smoke failed: '+$trMode)}
 Write-Output ('PASS Tropical source game launch '+$trMode)
}
