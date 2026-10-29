param([string]$Feature='')
$ErrorActionPreference='Stop'
$trProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$trGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$trModes=if($Feature){@($Feature)}else{@('painted_hills','hoodoo_cluster','rare_pool','grass_badlands_transition','forest_badlands_transition','jungle_badlands_transition','savanna_badlands_transition','swamp_badlands_transition','mountain_badlands_transition','tropical_badlands_transition','saved_world')}
foreach($trMode in $trModes){
 $trPrefix=Join-Path $trProject ('.godot\badlands_smoke_'+$trMode)
 $trArgs='--path "'+$trProject+'" --windowed --resolution 1280x720 --log-file "'+$trPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/badlands/artifacts/smoke_'+$trMode
 if($trMode -ne 'saved_world'){$trArgs+=' badlands-preview badlands-feature='+$trMode}
 $trChild=Start-Process -FilePath $trGodot -WorkingDirectory $trProject -ArgumentList $trArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($trPrefix+'.out.log') -RedirectStandardError ($trPrefix+'.err.log')
 $null=$trChild.Handle;$trStarted=[DateTime]::UtcNow
 while(-not $trChild.WaitForExit(500)){
  $trText=if(Test-Path -LiteralPath ($trPrefix+'.engine.log')){Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw}else{''}
  if($trText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$trStarted).TotalSeconds -gt 150){$trChild.Kill();$trChild.WaitForExit();throw ('Smoke failed/timed out: '+$trMode)}
 }
 $trChild.WaitForExit();$trChild.Refresh();$trText=Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw
 if($trChild.ExitCode -ne 0 -or $trText -notmatch 'RUNTIME_SMOKE_PASS' -or $trText -match 'ERROR:'){throw ('Smoke failed: '+$trMode)}
 Write-Output ('PASS Badlands source game launch '+$trMode)
}
