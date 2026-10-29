param([switch]$Review,[switch]$Benchmark,[switch]$Normal,[string]$Feature='')
$ErrorActionPreference='Stop'
$forestProject=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$forestGodot='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
$forestLog=Join-Path $forestProject '.godot\forest_tests'
New-Item -ItemType Directory -Force -Path $forestLog | Out-Null
$forestCases=@(@{script='check_invariants';gpu=$false;args=''},@{script='check_materials';gpu=$false;args=''})
if($Review){$forestCases+=@{script='check_gpu_channels';gpu=$true;args=''};$forestCases+=@{script='check_texture_precision';gpu=$true;args=''};$forestCases+=@{script='render_review';gpu=$true;args=$(if($Feature){' -- feature='+$Feature}else{''})}}
if($Normal){$forestCases+=@{script='check_normal_visibility';gpu=$true;args=''}}
if($Benchmark){foreach($forestMode in @('baseline','grass','forest')){if($forestMode -eq 'baseline' -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'baseline\builder.gd'))){Write-Warning 'Local pre-Forest snapshot unavailable; baseline comparison skipped.';continue};$forestCases+=@{script='benchmark';gpu=$true;args=(' -- mode='+$forestMode)}}}
foreach($forestCase in $forestCases){
 $forestPrefix=Join-Path $forestLog ($forestCase.script+$forestCase.args.Replace(' -- mode=','_').Replace(' -- feature=','_'))
 $forestArgs='--path "'+$forestProject+'" --log-file "'+$forestPrefix+'.engine.log" '+$(if($forestCase.gpu){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script res://tools/forest/'+$forestCase.script+'.gd'+$forestCase.args
 $forestChild=Start-Process -FilePath $forestGodot -WorkingDirectory $forestProject -ArgumentList $forestArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($forestPrefix+'.out.log') -RedirectStandardError ($forestPrefix+'.err.log')
 $null=$forestChild.Handle
 $forestStarted=[DateTime]::UtcNow
 while(-not $forestChild.WaitForExit(500)){
  $forestText=if(Test-Path -LiteralPath ($forestPrefix+'.engine.log')){Get-Content -LiteralPath ($forestPrefix+'.engine.log') -Raw}else{''}
  if($forestText -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$forestStarted).TotalSeconds -gt 900){$forestChild.Kill();$forestChild.WaitForExit();throw ('Failed/timed out: '+$forestPrefix)}
 }
 $forestChild.WaitForExit();$forestChild.Refresh()
 $forestText=Get-Content -LiteralPath ($forestPrefix+'.engine.log') -Raw
 if($forestChild.ExitCode -ne 0 -or $forestText -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$forestPrefix)}
 Write-Output ('PASS '+$forestCase.script+$forestCase.args)
}
Write-Output 'Forest verification finished. No export performed.'
