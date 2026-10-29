$ErrorActionPreference='Stop'
$coastProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$coastGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($coastMode in @('high_foredunes','lagoon','parabolic_dunes','grass_beach_transition','forest_beach_transition','jungle_beach_transition','savanna_beach_transition','swamp_beach_transition','mountain_beach_transition','saved_world')){
 $coastPrefix=Join-Path $coastProject ('.godot\beach_smoke_'+$coastMode)
 $coastArgs='--path "'+$coastProject+'" --windowed --resolution 1280x720 --log-file "'+$coastPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/beach/artifacts/smoke_'+$coastMode
 if($coastMode -ne 'saved_world'){$coastArgs+=' beach-preview beach-feature='+$coastMode}
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
