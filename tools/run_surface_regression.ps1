param()
$ErrorActionPreference='Stop'
$srRoot=Split-Path -Parent $PSScriptRoot
$srRunner=Join-Path $PSScriptRoot 'biome_extensions/run_test.ps1'
$srPaths=@('project.godot','scenes/main.tscn')+@(rg --files scripts shaders -g '*.gd' -g '*.gdshader' -g '*.gdshaderinc')+@(Get-ChildItem -LiteralPath (Join-Path $srRoot 'config') -Recurse -File -Filter '*.tres' | ForEach-Object {[IO.Path]::GetRelativePath($srRoot,$_.FullName).Replace('\','/')})
$srHashes=[ordered]@{}
foreach($srPath in $srPaths){$srHashes[$srPath]=(Get-FileHash -LiteralPath (Join-Path $srRoot $srPath) -Algorithm SHA256).Hash.ToLowerInvariant()}
$srTests=@('check_terrain_settings','check_cache_order','check_grass_terrain','check_terrain_shape_scale','check_settings_ownership') | ForEach-Object {'tools/'+$_+'.gd'}
foreach($srFamily in @('jungle','forest','savanna','swamp','mountain','rocky_coast','beach','tropical')){
 $srTests+=@('tools/'+$srFamily+'/check_invariants.gd')
 $srTests+=@('tools/'+$srFamily+'/'+$(if($srFamily -eq 'tropical'){'check_assets.gd'}else{'check_materials.gd'}))
}
foreach($srTest in @('check_all','check_integration','check_sample_alias','check_features','check_roundtrip','check_liquids','check_waterfalls','check_quarry_access','check_spore_ecology','check_assets')){$srTests+=@('tools/biome_extensions/'+$srTest+'.gd')}
$srRecords=@()
foreach($srTest in $srTests){
 $srName='surface_'+($srTest -replace '^tools/','' -replace '\.gd$','' -replace '/','_')
 $srStart=[DateTime]::UtcNow
 $srExtra=if($srTest -match '/check_(roundtrip|features|integration)\.gd$'){'--fixed-fps 60'}else{''}
 & $srRunner -Script $srName -ScriptFile ('res://'+$srTest) -Extra $srExtra
 $srEngineLog=Join-Path $srRoot ('.godot/extensions_'+$srName+'.engine.log')
 $srRecords+=@([ordered]@{script=$srTest;passed=$true;seconds=([DateTime]::UtcNow-$srStart).TotalSeconds;fixed_step_acceleration=($srExtra -ne '');script_sha256=(Get-FileHash -LiteralPath (Join-Path $srRoot $srTest) -Algorithm SHA256).Hash.ToLowerInvariant();engine_log_sha256=(Get-FileHash -LiteralPath $srEngineLog -Algorithm SHA256).Hash.ToLowerInvariant()})
}
foreach($srPath in $srPaths){if((Get-FileHash -LiteralPath (Join-Path $srRoot $srPath) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $srHashes[$srPath]){throw ('Source changed during surface regression: '+$srPath)}}
$srReport=[ordered]@{date=(Get-Date -Format 'yyyy-MM-dd');completed_utc=[DateTime]::UtcNow.ToString('o');passed=$true;test_count=$srRecords.Count;tests=$srRecords;source_sha256=$srHashes;scope='Sequential native headless numeric, asset and declared physics regressions; current source guard. No GPU timing, reference-quality sign-off, all-world traversal or infinite-cave claim.'}
$srOutput=Join-Path $srRoot 'data/surface_regression_20261018.json'
[System.IO.File]::WriteAllText($srOutput,($srReport | ConvertTo-Json -Depth 15),[System.Text.UTF8Encoding]::new($false))
Write-Output ('SURFACE_REGRESSION_PASS '+$srRecords.Count+' scripts; source unchanged')
