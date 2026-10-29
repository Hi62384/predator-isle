extends "res://tools/biome_extensions/check_all.gd"
const Host=preload("res://tools/biome_extensions/height_cache_builder_candidate.gd")
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
func run()->void:
	var hashes:Dictionary={}
	hashes["res://tools/biome_extensions/run_test.ps1"]=FileAccess.get_sha256("res://tools/biome_extensions/run_test.ps1")
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/height_cache_builder_candidate.gd","res://tools/biome_extensions/profile_coastal_height_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for repeat in range(3):
		var original:Array=[];var pair:Dictionary={};var order:Array=[8192,65536] if repeat%2==0 else [65536,8192]
		for capacity:int in order:
			var configured=make_builder(7,92881);var b=Host.new();b.settings=configured.settings;b.settings.alien_infected.feature_scale=.2;b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true;b.world_seed=92881;b.cache_limit=capacity;b._configure_noise();b.chunk_size=16384
			var coordinate:=Vector2i(-5,-7);var fields:Array=b.build(coordinate,16);var features=preload("res://scripts/terrain_feature_meshes.gd").new();var detail:Dictionary=features.build(b,coordinate)
			var g=Controller.new();g.conduit_cache_enabled=false;b.height_cache_hits=0;b.height_cache_misses=0;b.height_cache_resets=0
			var started:int=Time.get_ticks_usec();var structures:Array=g.build(b,coordinate,Structures.support_grids(),features.portal_sites);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
			var outputs:Array=[fields,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,detail,structures]
			if original.is_empty():original=outputs
			else:check(outputs==original,"Complete same-coastal-tile terrain/normal/atlas/features/structures exact at both capacities")
			check(structures[2]!=null and structures[2][Mesh.ARRAY_VERTEX].size()>1000000,"Same nonempty dense retained-contact workload required")
			pair[capacity]={"ms":elapsed,"hits":b.height_cache_hits,"misses":b.height_cache_misses,"resets":b.height_cache_resets,"vertices":structures[2][Mesh.ARRAY_VERTEX].size(),"retained_entries":b._normal_height_cache.size(),"serialized_bytes":var_to_bytes(b._normal_height_cache).size()}
			print("COASTAL_HEIGHT_CACHE_PAIR repeat=",repeat," capacity=",capacity," record=",pair[capacity])
		cases.append({"repeat":repeat,"original_8192":pair[8192],"trial_65536":pair[65536],"ratio":pair[65536].ms/maxf(pair[8192].ms,.001)})
	check(cases.size()==3,"All three alternating cold same-tile pairs")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private coastal height-cache source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_coastal_height_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":false,"scope":"Separate private capacity experiment on the coast-enabled retained-contact path, not the earlier coast-disabled full-detail height-cache result. Three serial alternating 8192/65536 normal-height memo pairs, identical actual dense seed92881/scale0.2 16km tile and complete outputs, same 16384-entry support cache and disabled mesh memo. Hit/miss/reset counters enabled equally; extra serialized bytes reported. No production cache/budget change, native timing/memory or general performance acceptance."},"  "))
	print("COASTAL_HEIGHT_CACHE_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
