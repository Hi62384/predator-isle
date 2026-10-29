$ErrorActionPreference='Stop'
$mountainProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mountainGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($mountainMode in @('jagged_alpine','valley_lake','grass_mountain_transition','forest_mountain_transition','jungle_mountain_transition','savanna_mountain_transition','swamp_mountain_transition','saved_world')){
 $mountainPrefix=Join-Path $mountainProject ('.godot\mountain_smoke_'+$mountainMode)
 $mountainArgs='--path "'+$mountainProject+'" --windowed --resolution 1280x720 --log-file "'+$mountainPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/mountain/artifacts/smoke_'+$mountainMode
 if($mountainMode -ne 'saved_world'){$mountainArgs+=' mountain-preview mountain-feature='+$mountainMode}
 $mountainChild=Start-Process -FilePath $mountainGodot -WorkingDirectory $mountainProject -ArgumentList $mountainArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($mountainPrefix+'.out.log') -RedirectStandardError ($mountainPrefix+'.err.log')
 $null=$mountainChild.Handle;$mountainStarted=[DateTime]::UtcNow
 while(-not $mountainChild.WaitForExit(500)){
  $mountainText=if(Test-Path -LiteralPath ($mountainPrefix+'.engine.log')){Get-Content -LiteralPath ($mountainPrefix+'.engine.log') -Raw}else{''}
  if($mountainText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$mountainStarted).TotalSeconds -gt 150){$mountainChild.Kill();$mountainChild.WaitForExit();throw ('Smoke failed/timed out: '+$mountainMode)}
 }
 $mountainChild.WaitForExit();$mountainChild.Refresh();$mountainText=Get-Content -LiteralPath ($mountainPrefix+'.engine.log') -Raw
 if($mountainChild.ExitCode -ne 0 -or $mountainText -notmatch 'RUNTIME_SMOKE_PASS' -or $mountainText -match 'ERROR:'){throw ('Smoke failed: '+$mountainMode)}
 Write-Output ('PASS source game launch '+$mountainMode)
}
