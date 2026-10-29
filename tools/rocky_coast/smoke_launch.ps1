$ErrorActionPreference='Stop'
$coastProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$coastGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($coastMode in @('towering_cliffs','tide_pools','isolated_stack','grass_coast_transition','forest_coast_transition','jungle_coast_transition','savanna_coast_transition','swamp_coast_transition','mountain_coast_transition','saved_world')){
 $coastPrefix=Join-Path $coastProject ('.godot\rocky_coast_smoke_'+$coastMode)
 $coastArgs='--path "'+$coastProject+'" --windowed --resolution 1280x720 --log-file "'+$coastPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/rocky_coast/artifacts/smoke_'+$coastMode
 if($coastMode -ne 'saved_world'){$coastArgs+=' coast-preview coast-feature='+$coastMode}
 $coastChild=Start-Process -FilePath $coastGodot -WorkingDirectory $coastProject -ArgumentList $coastArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($coastPrefix+'.out.log') -RedirectStandardError ($coastPrefix+'.err.log')
 $null=$coastChild.Handle;$coastStarted=[DateTime]::UtcNow
 while(-not $coastChild.WaitForExit(500)){
  $coastText=if(Test-Path -LiteralPath ($coastPrefix+'.engine.log')){Get-Content -LiteralPath ($coastPrefix+'.engine.log') -Raw}else{''}
  if($coastText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$coastStarted).TotalSeconds -gt 150){$coastChild.Kill();$coastChild.WaitForExit();throw ('Smoke failed/timed out: '+$coastMode)}
 }
 $coastChild.WaitForExit();$coastChild.Refresh();$coastText=Get-Content -LiteralPath ($coastPrefix+'.engine.log') -Raw
 if($coastChild.ExitCode -ne 0 -or $coastText -notmatch 'RUNTIME_SMOKE_PASS' -or $coastText -match 'ERROR:'){throw ('Smoke failed: '+$coastMode)}
 Write-Output ('PASS source game launch '+$coastMode)
}
