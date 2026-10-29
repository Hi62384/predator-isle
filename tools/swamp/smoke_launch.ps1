$ErrorActionPreference='Stop'
$swampProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$swampGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
foreach($swampMode in @('bayou','swamp_lake','grass_swamp_transition','forest_swamp_transition','jungle_swamp_transition','savanna_swamp_transition','saved_world')){
 $swampPrefix=Join-Path $swampProject ('.godot\swamp_smoke_'+$swampMode)
 $swampArgs='--path "'+$swampProject+'" --windowed --resolution 1280x720 --log-file "'+$swampPrefix+'.engine.log" -- smoke-test smoke-output=res://tools/swamp/artifacts/smoke_'+$swampMode
 if($swampMode -ne 'saved_world'){$swampArgs+=' swamp-preview swamp-feature='+$swampMode}
 $swampChild=Start-Process -FilePath $swampGodot -WorkingDirectory $swampProject -ArgumentList $swampArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($swampPrefix+'.out.log') -RedirectStandardError ($swampPrefix+'.err.log')
 $null=$swampChild.Handle;$swampStarted=[DateTime]::UtcNow
 while(-not $swampChild.WaitForExit(500)){
  $swampText=if(Test-Path -LiteralPath ($swampPrefix+'.engine.log')){Get-Content -LiteralPath ($swampPrefix+'.engine.log') -Raw}else{''}
  if($swampText -match 'ERROR:|Assertion failed' -or ([DateTime]::UtcNow-$swampStarted).TotalSeconds -gt 150){$swampChild.Kill();$swampChild.WaitForExit();throw ('Smoke failed/timed out: '+$swampMode)}
 }
 $swampChild.WaitForExit();$swampChild.Refresh();$swampText=Get-Content -LiteralPath ($swampPrefix+'.engine.log') -Raw
 if($swampChild.ExitCode -ne 0 -or $swampText -notmatch 'RUNTIME_SMOKE_PASS' -or $swampText -match 'ERROR:'){throw ('Smoke failed: '+$swampMode)}
 Write-Output ('PASS source game launch '+$swampMode)
}
