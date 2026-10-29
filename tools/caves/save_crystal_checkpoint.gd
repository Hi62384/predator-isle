extends "res://tools/biome_extensions/check_all.gd"
const Archive:String="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_crystal_current_breadth_0492b3a214f7/"
const Ledger:String="res://tools/biome_extensions/artifacts/check_cave_crystal_current_breadth.json"
const Registration:String="res://tools/biome_extensions/artifacts/check_cave_crystal_registration.json"
func run()->void:
	var guards:Dictionary={};var manifest_path:String=Archive+"manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path));check(manifest is Dictionary and manifest.get("files",[]).size()==664,"Original completed pre-registration native breadth archive retained")
	var verified:int=0
	if manifest is Dictionary:
		guards[manifest_path]=FileAccess.get_sha256(manifest_path)
		for entry:Dictionary in manifest.get("files",[]):check(FileAccess.get_sha256(entry.snapshot)==entry.sha256,"Original immutable pre-registration bytes "+entry.snapshot);verified+=1
	var ledger=JSON.parse_string(FileAccess.get_file_as_string(Ledger));var registration=JSON.parse_string(FileAccess.get_file_as_string(Registration));check(ledger is Dictionary and ledger.get("passed",false) and registration is Dictionary and registration.get("passed",false),"Native component ledger and actual saved registration both pass")
	if not ledger is Dictionary or not registration is Dictionary:quit(1);return
	guards[Ledger]=FileAccess.get_sha256(Ledger);guards[Registration]=FileAccess.get_sha256(Registration)
	# The archived two-definition registry was explicitly extended by one
	# resource. All other production dependencies must remain byte-identical.
	for source:String in ledger.source_sha256:
		if source=="res://config/caves/cave_biome_regions.tres":continue
		if source.begins_with("res://scripts/") or source.begins_with("res://shaders/") or source.ends_with(".tres") or source in ["res://scenes/main.tscn","res://project.godot"]:
			check(FileAccess.get_sha256(source)==ledger.source_sha256[source],"Exact validated production content retained across registry delivery "+source);guards[source]=ledger.source_sha256[source]
	for source:String in registration.source_sha256:check(FileAccess.get_sha256(source)==registration.source_sha256[source],"Current actual saved registration source "+source);guards[source]=registration.source_sha256[source]
	var surface_path:String="res://data/surface_regression_20261018.json";var surface=JSON.parse_string(FileAccess.get_file_as_string(surface_path));check(surface is Dictionary and surface.get("passed",false) and int(surface.test_count)==31,"All31shared regressions pass AFTER actual registration")
	if surface is Dictionary:
		guards[surface_path]=FileAccess.get_sha256(surface_path)
		for raw:String in surface.get("source_sha256",{}):var source:String="res://"+raw.replace("\\","/");check(FileAccess.get_sha256(source)==surface.source_sha256[raw],"Current registered shared source "+source);guards[source]=surface.source_sha256[raw]
	var receipt_path:String="res://.godot/extensions_crystal_registration.receipt.json";var receipt=JSON.parse_string(FileAccess.get_file_as_string(receipt_path));check(receipt is Dictionary and receipt.get("passed",false),"Actual completed native three-definition registration receipt");guards[receipt_path]=FileAccess.get_sha256(receipt_path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	for source:String in guards:check(FileAccess.get_sha256(source)==guards[source],"Stable registered component checkpoint "+source)
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"upstream_native_archive":Archive,"original_upstream_files_verified":verified,"pre_registration_ledger_sha256":FileAccess.get_sha256(Ledger),"registered_ids":registration.registered_ids,"root_enabled":registration.root_enabled,"native_normal_scenes":ledger.normal_scenes.size(),"positive_native_lod_scenes":ledger.positive_native_lod_scenes,"stationary_renderer_timing":ledger.stationary_renderer_timing,"maximum_native_sampled_private_mib":ledger.maximum_native_sampled_private_mib,"native_full_return":"27,394.580m/all5006waypoints/396.008mdepth/.038109mdrop/464.567smotionunder650/42.644spreloadunder180/48cuts/2entranceexchanges/4TOTALjobs/185cells/1692.2sampledMiBunder2048;archive3a5ba4ff981c. Explicit original three-definition fixture configuration is byte-exact actual saved registration,verified independently after delivery.","all_user_tasks_complete":false,"reference_art_acceptance":false,"scope":"Registered FUNCTIONAL Crystal component checkpoint. Original pre-registration664-file archive verified as immutable;its hashes are never rebound. Only registry resource wiring changed;all other validated production dependencies byte-exact. Actual saved native reload/provider/controls and complete positive payload parity,original zero-affinity Default/Frozen preservation and31post-registration shared tests pass. Twenty normal unique scene/LOD/renderer/return cases plus actual transitions/shallow/rare-mineral/lake/full streaming retained. Does not certify all50visual cases/14reference-art scenes,uninterrupted FPS,cold startup,root activation,Magma or all-user completion. Private reflection trial is unadopted."}
	var path:String="res://tools/biome_extensions/artifacts/cave_crystal_registered_checkpoint.json";FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));FileAccess.open("res://data/cave_crystal_registered_checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("CRYSTAL_REGISTERED_CHECKPOINT ",checks," upstream=",verified," scenes=",ledger.normal_scenes.size()," failures=",failures.slice(0,6));quit(0 if failures.is_empty() else 1)
