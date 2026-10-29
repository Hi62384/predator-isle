param([string]$Script="check_invariants",[string]$Extra="",[switch]$GPU)
$ErrorActionPreference="Stop"
$mtRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mtEngine="C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe"
$mtPrefix=Join-Path $mtRoot (".godot\beach_"+$Script.Replace('../','root_'))
$rcBatchMatch=[regex]::Match($Extra,'(?:^| )batch=([A-Za-z0-9_-]+)')
if($Script -eq 'render_review' -and $rcBatchMatch.Success){$mtPrefix+='_batch_'+$rcBatchMatch.Groups[1].Value}
$mtArgs='--path "'+$mtRoot+'" --log-file "'+$mtPrefix+'.engine.log" '+$(if($GPU){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/beach/'+$Script+'.gd '+$Extra
$mtChild=Start-Process -FilePath $mtEngine -WorkingDirectory $mtRoot -ArgumentList $mtArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($mtPrefix+'.out.log') -RedirectStandardError ($mtPrefix+'.err.log')
$null=$mtChild.Handle
$mtStart=[DateTime]::UtcNow
while(-not $mtChild.WaitForExit(500)){
 $mtText=if(Test-Path -LiteralPath ($mtPrefix+'.engine.log')){Get-Content -LiteralPath ($mtPrefix+'.engine.log') -Raw}else{""}
 if($mtText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$mtStart).TotalSeconds -gt 900){$mtChild.Kill();$mtChild.WaitForExit();throw ("Failed/timed out: "+$mtPrefix)}
}
$mtChild.WaitForExit();$mtChild.Refresh()
$mtText=Get-Content -LiteralPath ($mtPrefix+'.engine.log') -Raw
if($mtChild.ExitCode -ne 0 -or $mtText -match 'ERROR:|Assertion failed|Parse Error'){throw ("Failed: "+$mtPrefix)}
Write-Output ("PASS Beach "+$Script+" "+$Extra)
