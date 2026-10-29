param([Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9_]+$')][string]$Group,[Parameter(Mandatory=$true)][string[]]$Targets)
$ErrorActionPreference='Stop'
$sceneRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sceneRunner=Join-Path $sceneRoot 'tools/biome_extensions/run_test.ps1'
$sceneSnapshots=[ordered]@{}
foreach($sceneTool in @('tools/caves/render_magma_scenic_target.gd','tools/caves/render_magma_world.gd','tools/caves/render_frozen_world.gd','tools/caves/check_frozen_world_cohort.gd','tools/caves/frozen_fixture.gd','tools/caves/inspection_scope.gd','tools/biome_extensions/route_probe.gd')){
 $sceneToolPath=Join-Path $sceneRoot $sceneTool
 $sceneHash=(Get-FileHash -LiteralPath $sceneToolPath -Algorithm SHA256).Hash.ToLowerInvariant()
 $sceneSnapshot='tools/biome_extensions/artifacts/magma_scene_tool_'+$sceneHash+'.gd.txt'
 $sceneSnapshotPath=Join-Path $sceneRoot $sceneSnapshot
 if(Test-Path -LiteralPath $sceneSnapshotPath){if((Get-FileHash -LiteralPath $sceneSnapshotPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sceneHash){throw 'Immutable scene-tool snapshot mismatch'}}else{Copy-Item -LiteralPath $sceneToolPath -Destination $sceneSnapshotPath}
 $sceneSnapshots['res://'+$sceneTool]=[ordered]@{sha256=$sceneHash;snapshot=('res://'+$sceneSnapshot)}
}
$sceneRecords=[System.Collections.Generic.List[object]]::new()
foreach($sceneTarget in $Targets){
 if($sceneTarget -notmatch '^[a-z][a-z0-9_]+$'){throw 'Invalid scene target'}
 $sceneToken=([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($sceneTarget)))).Substring(0,10).ToLowerInvariant()
 $sceneLabel='magma_scenic_'+$sceneToken
 $sceneStarted=[DateTime]::UtcNow
 $scenePassed=$false;$sceneFailure=''
 try{
  & $sceneRunner -Script $sceneLabel -ScriptFile 'res://tools/caves/render_magma_scenic_target.gd' -GPU -Extra ('--fixed-fps 60 -- target='+$sceneTarget) -MemoryLimitMiB 2048
  $scenePassed=$true
 }catch{$sceneFailure=$_.Exception.Message}
 $sceneReport='tools/biome_extensions/artifacts/render_cave_magma_scene_'+$sceneTarget+'.json'
 $sceneReportPath=Join-Path $sceneRoot $sceneReport
 $sceneReportHash=$null
 if((Test-Path -LiteralPath $sceneReportPath) -and (Get-Item -LiteralPath $sceneReportPath).LastWriteTimeUtc -ge $sceneStarted){$sceneReportHash=(Get-FileHash -LiteralPath $sceneReportPath -Algorithm SHA256).Hash.ToLowerInvariant()}
 $sceneOutputs=[ordered]@{}
 foreach($sceneSuffix in @('out.log','err.log','engine.log','receipt.json')){
  $sceneOutput='.godot/extensions_'+$sceneLabel+'.'+$sceneSuffix
  $sceneOutputPath=Join-Path $sceneRoot $sceneOutput
  if((Test-Path -LiteralPath $sceneOutputPath) -and (Get-Item -LiteralPath $sceneOutputPath).LastWriteTimeUtc -ge $sceneStarted){$sceneOutputs['res://'+$sceneOutput]=(Get-FileHash -LiteralPath $sceneOutputPath -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 $sceneRecords.Add([ordered]@{target=$sceneTarget;passed=$scenePassed;failure=$sceneFailure;started_utc=$sceneStarted.ToString('o');completed_utc=[DateTime]::UtcNow.ToString('o');report=('res://'+$sceneReport);report_sha256=$sceneReportHash;outputs=$sceneOutputs})
 Write-Output ('MAGMA_SCENE_RESULT '+$sceneTarget+' passed='+$scenePassed)
}
$sceneFailed=@($sceneRecords | Where-Object {-not $_.passed})
$sceneBatch=[ordered]@{passed=($sceneFailed.Count -eq 0);group=$Group;records=$sceneRecords;tool_snapshots=$sceneSnapshots;scope='Sequential owned native cases in this batch;may run alongside another independent batch and user Godot sessions. All successes and failures retained. Original source-bound reports and immutable tool snapshots preserved for a single phase collector before production edits. 2048MiB per-owned-engine limit,not aggregate or isolated performance.'}
$sceneBatchPath=Join-Path $sceneRoot ('tools/biome_extensions/artifacts/magma_scene_batch_'+$Group+'.json')
[System.IO.File]::WriteAllText($sceneBatchPath,($sceneBatch | ConvertTo-Json -Depth 12),[System.Text.UTF8Encoding]::new($false))
if($sceneFailed.Count -gt 0){exit 1}
