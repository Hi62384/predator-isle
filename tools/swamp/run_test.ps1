param([string]$Script="check_invariants",[string]$Extra="",[switch]$GPU)
$ErrorActionPreference="Stop"
$swRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$swEngine="C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe"
$swPrefix=Join-Path $swRoot (".godot\swamp_"+$Script)
$swArgs='--path "'+$swRoot+'" --log-file "'+$swPrefix+'.engine.log" '+$(if($GPU){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/swamp/'+$Script+'.gd '+$Extra
$swChild=Start-Process -FilePath $swEngine -WorkingDirectory $swRoot -ArgumentList $swArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($swPrefix+'.out.log') -RedirectStandardError ($swPrefix+'.err.log')
$null=$swChild.Handle
$swStart=[DateTime]::UtcNow
while(-not $swChild.WaitForExit(500)){
 $swText=if(Test-Path -LiteralPath ($swPrefix+'.engine.log')){Get-Content -LiteralPath ($swPrefix+'.engine.log') -Raw}else{""}
 if($swText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$swStart).TotalSeconds -gt 900){$swChild.Kill();$swChild.WaitForExit();throw ("Failed/timed out: "+$swPrefix)}
}
$swChild.WaitForExit();$swChild.Refresh()
$swText=Get-Content -LiteralPath ($swPrefix+'.engine.log') -Raw
if($swChild.ExitCode -ne 0 -or $swText -match 'ERROR:|Assertion failed|Parse Error'){throw ("Failed: "+$swPrefix)}
Write-Output ("PASS Swamp "+$Script+" "+$Extra)
