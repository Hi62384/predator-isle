param([switch]$Review,[switch]$Benchmark,[switch]$Normal,[string]$Feature='')
$ErrorActionPreference='Stop'
$savannaProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$savannaGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$savannaLog=Join-Path $savannaProject '.godot\savanna_tests'
New-Item -ItemType Directory -Force -Path $savannaLog | Out-Null
$savannaCases=@(@{script='check_invariants';gpu=$false;args=''},@{script='check_materials';gpu=$false;args=''})
if($Review){$savannaCases+=@{script='check_gpu_channels';gpu=$true;args=''};$savannaCases+=@{script='check_texture_precision';gpu=$true;args=''};$savannaCases+=@{script='render_review';gpu=$true;args=$(if($Feature){' -- feature='+$Feature}else{''})}}
if($Normal){$savannaCases+=@{script='check_normal_visibility';gpu=$true;args=''}}
if($Benchmark){foreach($savannaMode in @('baseline','grass','savanna')){if($savannaMode -eq 'baseline' -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'baseline\builder.gd'))){Write-Warning 'Local pre-Savanna snapshot unavailable; baseline comparison skipped.';continue};$savannaCases+=@{script='benchmark';gpu=$true;args=(' -- mode='+$savannaMode)}}}
foreach($savannaCase in $savannaCases){
 $savannaPrefix=Join-Path $savannaLog ($savannaCase.script+$savannaCase.args.Replace(' -- mode=','_').Replace(' -- feature=','_'))
 $savannaArgs='--path "'+$savannaProject+'" --log-file "'+$savannaPrefix+'.engine.log" '+$(if($savannaCase.gpu){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/savanna/'+$savannaCase.script+'.gd'+$savannaCase.args
 $savannaChild=Start-Process -FilePath $savannaGodot -WorkingDirectory $savannaProject -ArgumentList $savannaArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($savannaPrefix+'.out.log') -RedirectStandardError ($savannaPrefix+'.err.log')
 $null=$savannaChild.Handle
 $savannaStarted=[DateTime]::UtcNow
 while(-not $savannaChild.WaitForExit(500)){
  $savannaText=if(Test-Path -LiteralPath ($savannaPrefix+'.engine.log')){Get-Content -LiteralPath ($savannaPrefix+'.engine.log') -Raw}else{''}
  if($savannaText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$savannaStarted).TotalSeconds -gt 900){$savannaChild.Kill();$savannaChild.WaitForExit();throw ('Failed/timed out: '+$savannaPrefix)}
 }
 $savannaChild.WaitForExit();$savannaChild.Refresh()
 $savannaText=Get-Content -LiteralPath ($savannaPrefix+'.engine.log') -Raw
 if($savannaChild.ExitCode -ne 0 -or $savannaText -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$savannaPrefix)}
 Write-Output ('PASS '+$savannaCase.script+$savannaCase.args)
}
Write-Output 'Savanna verification finished. No export performed.'
