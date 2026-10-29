param([string]$Script='check_all',[string]$Extra='',[switch]$GPU,[string]$ScriptFile='',[ValidateRange(0,65536)][int]$MemoryLimitMiB=0,[switch]$RequireIsolatedEngine)
$ErrorActionPreference='Stop'
$extRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# The 198KiB console executable is a launcher, not the rendering engine.
# Launch the engine directly so limits/errors terminate the actual fixture.
$extEngine='C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe'
$extPrefix=Join-Path $extRoot ('.godot\extensions_'+$Script)
$extScriptPath=if($ScriptFile){$ScriptFile}else{'res://tools/biome_extensions/'+$Script+'.gd'}
if($RequireIsolatedEngine -and @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Exclusive benchmark not started: another Godot process is active; it was left untouched'}
$extArgs='--path "'+$extRoot+'" --log-file "'+$extPrefix+'.engine.log" '+$(if($GPU){'--windowed --resolution 1280x720 '}else{'--headless '})+'--script '+$extScriptPath+' '+$Extra
$extFixedFps=if($Extra -match '(?:^|\s)--fixed-fps\s+(\d+)(?:\s|$)'){$Matches[1]}else{'none'}
# Godot strips recognized engine flags from OS.get_cmdline_args(). Pass a
# child-only marker from the exact declared arguments instead of guessing.
$extChild=Start-Process -FilePath $extEngine -WorkingDirectory $extRoot -ArgumentList $extArgs -WindowStyle Hidden -PassThru -Environment @{PREDATOR_TEST_ENGINE_FIXED_FPS=$extFixedFps} -RedirectStandardOutput ($extPrefix+'.out.log') -RedirectStandardError ($extPrefix+'.err.log')
$null=$extChild.Handle;$extStart=[DateTime]::UtcNow;$extPeakPrivate=0L
if($MemoryLimitMiB -gt 0){Write-Output ('RESOURCE_WATCH_START '+$Script+' engine_pid='+$extChild.Id+' executable='+[System.IO.Path]::GetFileName($extEngine)+' limit_mib='+$MemoryLimitMiB)}
while(-not $extChild.WaitForExit(500)){
	if($RequireIsolatedEngine){
	 $extOthers=@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $extChild.Id })
	 if($extOthers.Count -gt 0){$extChild.Kill();$extChild.WaitForExit();throw 'Exclusive benchmark interrupted by another Godot process; only this fixture child was stopped, and no isolated timing result is accepted'}
	}
	if($MemoryLimitMiB -gt 0){
	 $extChild.Refresh()
	 if(-not $extChild.HasExited){
	  $extPrivate=$extChild.PrivateMemorySize64;$extPeakPrivate=[math]::Max($extPeakPrivate,$extPrivate)
	  if($extPrivate -gt $MemoryLimitMiB*1MB){$extChild.Kill();$extChild.WaitForExit();throw ('Resource limit: '+$Script+' private memory '+[math]::Round($extPrivate/1MB,1)+' MiB exceeds predeclared '+$MemoryLimitMiB+' MiB; only this fixture child was stopped')}
	 }
	}
 $extText=if(Test-Path -LiteralPath ($extPrefix+'.engine.log')){Get-Content -LiteralPath ($extPrefix+'.engine.log') -Raw}else{''}
 $extErrors=if(Test-Path -LiteralPath ($extPrefix+'.err.log')){Get-Content -LiteralPath ($extPrefix+'.err.log') -Raw}else{''}
 if(($extText+$extErrors) -match 'ERROR:|Assertion failed|Parse Error' -or ([DateTime]::UtcNow-$extStart).TotalSeconds -gt 900){$extChild.Kill();$extChild.WaitForExit();throw ('Failed/timed out: '+$extPrefix)}
}
$extChild.WaitForExit();$extChild.Refresh();$extText=Get-Content -LiteralPath ($extPrefix+'.engine.log') -Raw
$extErrors=if(Test-Path -LiteralPath ($extPrefix+'.err.log')){Get-Content -LiteralPath ($extPrefix+'.err.log') -Raw}else{''}
if($extChild.ExitCode -ne 0 -or ($extText+$extErrors) -match 'ERROR:|Assertion failed|Parse Error'){throw ('Failed: '+$extPrefix)}
Write-Output ('PASS extensions '+$Script+' '+$Extra)
if($RequireIsolatedEngine){Write-Output ('ISOLATION_BOUND '+$Script+' no_other_godot_observed sample_period_ms=500; shorter overlaps are not excluded')}
if($MemoryLimitMiB -gt 0){Write-Output ('RESOURCE_BOUND '+$Script+' sampled_peak_private_mib='+[math]::Round($extPeakPrivate/1MB,1)+' limit_mib='+$MemoryLimitMiB+' sample_period_ms=500')}
# Persist completed runner observations separately from the fixture's semantic
# report. Zero samples remain explicitly unsampled, never a zero-memory claim.
$extReceipt=[ordered]@{passed=$true;script=$extScriptPath;extra_arguments=$Extra;engine_pid=$extChild.Id;started_utc=$extStart.ToString('o');completed_utc=[DateTime]::UtcNow.ToString('o');exit_code=$extChild.ExitCode;memory_limit_mib=$MemoryLimitMiB;sample_period_ms=500;sampled_peak_private_bytes=$(if($extPeakPrivate -gt 0){$extPeakPrivate}else{$null});isolation_requested=[bool]$RequireIsolatedEngine;scope='Owned native engine completed without observed error or declared limit violation. Memory is a500ms sampled private-memory observation,not an absolute peak;null means unsampled. No GPU/FPS claim.'}
[System.IO.File]::WriteAllText(($extPrefix+'.receipt.json'),($extReceipt | ConvertTo-Json -Depth 4),[System.Text.UTF8Encoding]::new($false))
