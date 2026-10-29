param([string]$Script="check_invariants",[string]$Extra="",[switch]$GPU)
$ErrorActionPreference="Stop"
$trRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$trEngine="C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe"
$trPrefix=Join-Path $trRoot (".godot\tropical_"+$Script)
$trArgs='--path "'+$trRoot+'" --log-file "'+$trPrefix+'.engine.log" '+$(if($GPU){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/tropical/'+$Script+'.gd '+$Extra
$trChild=Start-Process -FilePath $trEngine -WorkingDirectory $trRoot -ArgumentList $trArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($trPrefix+'.out.log') -RedirectStandardError ($trPrefix+'.err.log')
$null=$trChild.Handle
$trStart=[DateTime]::UtcNow
while(-not $trChild.WaitForExit(500)){
 $trText=if(Test-Path -LiteralPath ($trPrefix+'.engine.log')){Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw}else{""}
 if($trText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$trStart).TotalSeconds -gt 900){$trChild.Kill();$trChild.WaitForExit();throw ("Failed/timed out: "+$trPrefix)}
}
$trChild.WaitForExit();$trChild.Refresh()
$trText=Get-Content -LiteralPath ($trPrefix+'.engine.log') -Raw
if($trChild.ExitCode -ne 0 -or $trText -match 'ERROR:|Assertion failed|Parse Error'){throw ("Failed: "+$trPrefix)}
Write-Output ("PASS Tropical "+$Script+" "+$Extra)
