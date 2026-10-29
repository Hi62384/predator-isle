extends "res://tools/biome_extensions/check_all.gd"
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
const Candidate=preload("res://tools/biome_extensions/partitioned_support_cache_candidate.gd")
class SyntheticHost:
	extends RefCounted
	var calls:int=0
	func _sample_normal_height(x:float,z:float)->float:
		calls+=1;return sin(x*.001)*17+cos(z*.002)*13+x*.00001
func configured(seed_id:int,mode:String,scale_value:float):
	var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value
	if mode=="coastal":b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
	else:
		b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50 if mode=="mixed" else 0
		if mode=="overlay_only":b.settings.alien_infected.overlay_strength=.75
	b._configure_noise();return b
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/partitioned_support_cache_candidate.gd","res://tools/biome_extensions/check_partitioned_support_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var old=Controller.new();var trial=Candidate.new();var a:=SyntheticHost.new();var b:=SyntheticHost.new();var steps:=PackedFloat64Array([2,16,64,1024]);old._support_steps=steps;trial._support_steps=steps
	check(old._grid_height(a,7,-9,3,1024)==trial._grid_height(b,7,-9,3,1024),"Exact initial coarse support value")
	for i in range(20000):
		check(old._grid_height(a,i-10000,i%317,0,2)==trial._grid_height(b,i-10000,i%317,0,2),"Exact fine support value through real bounded eviction")
		check(trial._support_heights.size()<=16384,"Unchanged total dictionary-entry bound, including policy metadata")
	var original_before:int=a.calls;var trial_before:int=b.calls
	check(old._grid_height(a,7,-9,3,1024)==trial._grid_height(b,7,-9,3,1024),"Exact coarse result after fine-grid churn")
	check(a.calls==original_before+1 and b.calls==trial_before,"Original whole-cache clearing negative versus retained coarse FIFO hit")
	var before:int=trial._support_heights.size()
	for coordinate:int in [2147483648,-2147483649]:
		check(old._grid_height(a,coordinate,2,1,16)==trial._grid_height(b,coordinate,2,1,16),"Exact out-of-key-range support query, never rounded")
	check(trial._support_heights.size()==before,"Out-of-range values do not grow or corrupt the bounded cache")
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			for mode:String in ["mixed","coastal","overlay_only"]:
				var baseline=configured(seed_id,mode,scale_value);var candidate=configured(seed_id,mode,scale_value);baseline.chunk_size=4096;candidate.chunk_size=4096
				var coordinate:=Vector2i(-19,-26);var original_fields:Array=baseline.build(coordinate,16);var trial_fields:Array=candidate.build(coordinate,16)
				var original_features=preload("res://scripts/terrain_feature_meshes.gd").new();var trial_features=preload("res://scripts/terrain_feature_meshes.gd").new()
				var original_detail:Dictionary=original_features.build(baseline,coordinate);var trial_detail:Dictionary=trial_features.build(candidate,coordinate)
				var original_emitter=Controller.new();var trial_emitter=Candidate.new();original_emitter.conduit_cache_enabled=false;trial_emitter.conduit_cache_enabled=false
				var original_mesh:Array=original_emitter.build(baseline,coordinate,Controller.support_grids(),original_features.portal_sites);var trial_mesh:Array=trial_emitter.build(candidate,coordinate,Controller.support_grids(),trial_features.portal_sites)
				check(original_fields==trial_fields and baseline.built_extension_data==candidate.built_extension_data,"Complete canonical terrain/normal/atlas arrays exact")
				check(original_detail==trial_detail and original_mesh==trial_mesh,"Complete finite-feature and all structure position/normal/colour/UV arrays exact")
				check(trial_emitter._support_heights.size()<=16384,"Actual emitted-node support cache retains the original bound")
				cases.append({"seed":seed_id,"scale":scale_value,"mode":mode,"structure_vertices":trial_mesh[2][Mesh.ARRAY_VERTEX].size() if trial_mesh[2]!=null else 0,"retained_dictionary_entries":trial_emitter._support_heights.size(),"serialized_support_cache_bytes":var_to_bytes(trial_emitter._support_heights).size()})
	check(cases.size()==27,"All declared seed/scale/mixed/shore-enabled/partial-overlay configurations")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private support-cache source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_partitioned_support_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":false,"scope":"Private exact support-corner cache policy, immutable worker host/grid layout per cache object: synthetic 20000-query eviction with original clear-all negative and retained coarse hit, exact out-of-key-range bypass, complete terrain/normal/metadata/finite-feature/structure outputs over 27 seeded mixed/shore-enabled/partial-overlay configurations. Same 16384 total dictionary entries including FIFO metadata; serialized bytes reported, not assumed equal. Empty actual tiles may occur and are recorded, not speed evidence. No production adoption, timing/native memory or arbitrary live reconfiguration certificate."},"  "))
	print("PARTITIONED_SUPPORT_CACHE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
