param([string]$Script='check_invariants',[string]$Extra='',[switch]$GPU,[int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$blRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$blEngine='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$blPrefix=Join-Path $blRoot ('.godot\badlands_'+$Script)
$blArgs='--path "'+$blRoot+'" --log-file "'+$blPrefix+'.engine.log" '+$(if($GPU){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/badlands/'+$Script+'.gd '+$Extra
$blChild=Start-Process -FilePath $blEngine -WorkingDirectory $blRoot -ArgumentList $blArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($blPrefix+'.out.log') -RedirectStandardError ($blPrefix+'.err.log')
$null=$blChild.Handle;$blStart=[DateTime]::UtcNow
while(-not $blChild.WaitForExit(500)){
 $blText=if(Test-Path -LiteralPath ($blPrefix+'.engine.log')){Get-Content -LiteralPath ($blPrefix+'.engine.log') -Raw}else{''}
 $blErrors=if(Test-Path -LiteralPath ($blPrefix+'.err.log')){Get-Content -LiteralPath ($blPrefix+'.err.log') -Raw}else{''}
 if(($blText+$blErrors) -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$blStart).TotalSeconds -gt $TimeoutSeconds){$blChild.Kill();$blChild.WaitForExit();throw ('Failed/timed out: '+$blPrefix)}
}
$blChild.WaitForExit();$blChild.Refresh();$blText=Get-Content -LiteralPath ($blPrefix+'.engine.log') -Raw
$blErrors=if(Test-Path -LiteralPath ($blPrefix+'.err.log')){Get-Content -LiteralPath ($blPrefix+'.err.log') -Raw}else{''}
if($blChild.ExitCode -ne 0 -or ($blText+$blErrors) -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$blPrefix)}
Write-Output ('PASS Badlands '+$Script+' '+$Extra)
