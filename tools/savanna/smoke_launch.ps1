$ErrorActionPreference='Stop'
$savannaProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$savannaGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($savannaMode in @('isolated_kopje','grass_savanna_transition','forest_savanna_transition','jungle_savanna_transition','saved_world')){
 $savannaPrefix=Join-Path $savannaProject ('.godot\savanna_smoke_'+$savannaMode)
 $savannaArgs='--path "'+$savannaProject+'" --windowed --resolution 1280x720 --log-file "'+$savannaPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/savanna/artifacts/smoke_'+$savannaMode
 if($savannaMode -ne 'saved_world'){$savannaArgs+=' savanna-preview savanna-feature='+$savannaMode}
 $savannaChild=Start-Process -FilePath $savannaGodot -WorkingDirectory $savannaProject -ArgumentList $savannaArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($savannaPrefix+'.out.log') -RedirectStandardError ($savannaPrefix+'.err.log')
 $null=$savannaChild.Handle;$savannaStarted=[DateTime]::UtcNow
 while(-not $savannaChild.WaitForExit(500)){
  $savannaText=if(Test-Path -LiteralPath ($savannaPrefix+'.engine.log')){Get-Content -LiteralPath ($savannaPrefix+'.engine.log') -Raw}else{''}
  if($savannaText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$savannaStarted).TotalSeconds -gt 150){$savannaChild.Kill();$savannaChild.WaitForExit();throw ('Smoke failed/timed out: '+$savannaMode)}
 }
 $savannaChild.WaitForExit();$savannaChild.Refresh();$savannaText=Get-Content -LiteralPath ($savannaPrefix+'.engine.log') -Raw
 if($savannaChild.ExitCode -ne 0 -or $savannaText -notmatch 'RUNTIME_SMOKE_PASS' -or $savannaText -match 'ERROR:'){throw ('Smoke failed: '+$savannaMode)}
 Write-Output ('PASS source game launch '+$savannaMode)
}
