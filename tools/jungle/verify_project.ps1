param([switch]$Review,[switch]$Benchmark,[switch]$Regression,[switch]$Normal)
$ErrorActionPreference='Stop'
$jungleProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$jungleGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$jungleLog=Join-Path $jungleProject '.godot\jungle_tests'
New-Item -ItemType Directory -Force -Path $jungleLog | Out-Null
$jungleCases=@(@{script='check_invariants';gpu=$false;args=''},@{script='check_materials';gpu=$false;args=''},@{script='check_placement';gpu=$false;args=''},@{script='check_active_biomes';gpu=$false;args=''})
if($Review){$jungleCases+=@{script='check_gpu_channels';gpu=$true;args=''};$jungleCases+=@{script='render_review';gpu=$true;args=''};$jungleCases+=@{script='check_normal_visibility';gpu=$true;args=''}}
if($Normal -and -not $Review){$jungleCases+=@{script='check_normal_visibility';gpu=$true;args=''}}
if($Benchmark){foreach($jungleMode in @('grass','jungle')){if($jungleMode -eq 'baseline' -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'baseline\builder.gd'))){Write-Warning 'Local pre-Jungle baseline unavailable; no before-change comparison will be claimed.';continue};$jungleCases+=@{script='benchmark';gpu=$true;args=(' -- mode='+$jungleMode)}}}
foreach($jungleCase in $jungleCases){
 $junglePrefix=Join-Path $jungleLog ($jungleCase.script+$jungleCase.args.Replace(' -- mode=','_'))
 $jungleArgs='--path "'+$jungleProject+'" --log-file "'+$junglePrefix+'.engine.log" '+$(if($jungleCase.gpu){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/jungle/'+$jungleCase.script+'.gd'+$jungleCase.args
 $jungleChild=Start-Process -FilePath $jungleGodot -WorkingDirectory $jungleProject -ArgumentList $jungleArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($junglePrefix+'.out.log') -RedirectStandardError ($junglePrefix+'.err.log')
 $null=$jungleChild.Handle
 $jungleStarted=[DateTime]::UtcNow
 while(-not $jungleChild.WaitForExit(500)){
  $jungleText=if(Test-Path -LiteralPath ($junglePrefix+'.engine.log')){Get-Content -LiteralPath ($junglePrefix+'.engine.log') -Raw}else{''}
  if($jungleText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$jungleStarted).TotalSeconds -gt 900){$jungleChild.Kill();$jungleChild.WaitForExit();throw ('Failed/timed out: '+$junglePrefix)}
 }
 $jungleChild.WaitForExit();$jungleChild.Refresh()
 $jungleText=Get-Content -LiteralPath ($junglePrefix+'.engine.log') -Raw
 if($jungleChild.ExitCode -ne 0 -or $jungleText -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$junglePrefix)}
 Write-Output ('PASS '+$jungleCase.script+$jungleCase.args)
}
if($Regression){Write-Output 'Legacy Snow/Desert suites retired with those biomes. Grass/Jungle invariants and active-biome tests run above.'}
Write-Output 'Jungle verification finished. No export performed.'
