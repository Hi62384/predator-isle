$ErrorActionPreference='Stop'
$forestProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$forestGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($forestMode in @('mountain_forest','grass_forest_transition','forest_jungle_transition','saved_world')){
 $forestPrefix=Join-Path $forestProject ('.godot\forest_smoke_'+$forestMode)
 $forestArgs='--path "'+$forestProject+'" --windowed --resolution 1280x720 --log-file "'+$forestPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/forest/artifacts/smoke_'+$forestMode
 if($forestMode -ne 'saved_world'){$forestArgs+=' forest-preview forest-feature='+$forestMode}
 $forestChild=Start-Process -FilePath $forestGodot -WorkingDirectory $forestProject -ArgumentList $forestArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($forestPrefix+'.out.log') -RedirectStandardError ($forestPrefix+'.err.log')
 $null=$forestChild.Handle;$forestStarted=[DateTime]::UtcNow
 while(-not $forestChild.WaitForExit(500)){
  $forestText=if(Test-Path -LiteralPath ($forestPrefix+'.engine.log')){Get-Content -LiteralPath ($forestPrefix+'.engine.log') -Raw}else{''}
  if($forestText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$forestStarted).TotalSeconds -gt 150){$forestChild.Kill();$forestChild.WaitForExit();throw ('Smoke failed/timed out: '+$forestMode)}
 }
 $forestChild.WaitForExit();$forestChild.Refresh();$forestText=Get-Content -LiteralPath ($forestPrefix+'.engine.log') -Raw
 if($forestChild.ExitCode -ne 0 -or $forestText -notmatch 'RUNTIME_SMOKE_PASS' -or $forestText -match 'ERROR:'){throw ('Smoke failed: '+$forestMode)}
 Write-Output ('PASS source game launch '+$forestMode)
}
