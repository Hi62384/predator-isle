param([ValidateSet('all','alien_infected')][string]$Biome='all')
$ErrorActionPreference='Stop'
$extRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$extEngine='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$extPrefix=Join-Path $extRoot ('.godot\extensions_smoke_'+$Biome)
$extMode=if($Biome -eq 'all'){'all-biomes'}else{'biome='+$Biome}
$extArgs='--path "'+$extRoot+'" --windowed --resolution 1280x720 --log-file "'+$extPrefix+'.engine.log" -- smoke-test extension-debug-smoke smoke-output=res://tools/biome_extensions/artifacts/smoke_'+$Biome+' '+$extMode
$extChild=Start-Process -FilePath $extEngine -WorkingDirectory $extRoot -ArgumentList $extArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($extPrefix+'.out.log') -RedirectStandardError ($extPrefix+'.err.log')
$null=$extChild.Handle;$extStart=[DateTime]::UtcNow
while(-not $extChild.WaitForExit(500)){
 $extText=if(Test-Path -LiteralPath ($extPrefix+'.engine.log')){Get-Content -LiteralPath ($extPrefix+'.engine.log') -Raw}else{''}
 if($extText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$extStart).TotalSeconds -gt 240){$extChild.Kill();$extChild.WaitForExit();throw ('Failed/timed out: '+$extPrefix)}
}
$extChild.WaitForExit();$extChild.Refresh();$extText=Get-Content -LiteralPath ($extPrefix+'.engine.log') -Raw
if($extChild.ExitCode -ne 0 -or $extText -notmatch 'RUNTIME_SMOKE_PASS' -or $extText -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$extPrefix)}
Write-Output ('PASS game smoke '+$Biome)
