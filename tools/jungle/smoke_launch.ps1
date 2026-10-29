$ErrorActionPreference='Stop'
$jungleProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$jungleGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($jungleMode in @('jungle_mountains','grass_jungle_transition','saved_world')){
 $junglePrefix=Join-Path $jungleProject ('.godot\jungle_smoke_'+$jungleMode)
 $jungleArgs='--path "'+$jungleProject+'" --windowed --resolution 1280x720 --log-file "'+$junglePrefix+'.engine.log" -- smoke-test smoke-output=res://tools/jungle/artifacts/smoke_'+$jungleMode
 if($jungleMode -ne 'saved_world'){$jungleArgs+=' jungle-preview jungle-feature='+$jungleMode}
 $jungleChild=Start-Process -FilePath $jungleGodot -WorkingDirectory $jungleProject -ArgumentList $jungleArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($junglePrefix+'.out.log') -RedirectStandardError ($junglePrefix+'.err.log')
 $null=$jungleChild.Handle;$jungleStarted=[DateTime]::UtcNow
 while(-not $jungleChild.WaitForExit(500)){
  $jungleText=if(Test-Path -LiteralPath ($junglePrefix+'.engine.log')){Get-Content -LiteralPath ($junglePrefix+'.engine.log') -Raw}else{''}
  if($jungleText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$jungleStarted).TotalSeconds -gt 150){$jungleChild.Kill();$jungleChild.WaitForExit();throw ('Smoke failed/timed out: '+$jungleMode)}
 }
 $jungleChild.WaitForExit();$jungleChild.Refresh();$jungleText=Get-Content -LiteralPath ($junglePrefix+'.engine.log') -Raw
 if($jungleChild.ExitCode -ne 0 -or $jungleText -notmatch 'RUNTIME_SMOKE_PASS' -or $jungleText -match 'ERROR:'){throw ('Smoke failed: '+$jungleMode)}
 Write-Output ('PASS source game launch '+$jungleMode)
}
