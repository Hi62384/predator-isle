extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/height_cache_builder_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/height_cache_builder_candidate.gd","res://tools/biome_extensions/profile_dense_height_cache.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[];var baseline:Array=[]
	# The first unfinished LOD6 worker in the independently preserved failing
	# preload, not a newly selected easy site. All morphology/cavity guards on.
	for capacity:int in [8192,65536]:
		var b=Candidate.new();var configured=make_builder(7,92881);b.settings=configured.settings;b.settings.alien_infected.feature_scale=.2;b.world_seed=92881;b._configure_noise();b.chunk_size=16384;b.cache_limit=capacity
		var coordinate:=Vector2i(-5,-7);var started:int=Time.get_ticks_usec();var terrain_arrays:Array=b.build(coordinate,16);var terrain_ms:float=(Time.get_ticks_usec()-started)/1000.0
		var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();started=Time.get_ticks_usec();var features:Dictionary=mesher.build(b,coordinate);var features_ms:float=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec();var structures:Array=Structures.new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var structure_ms:float=(Time.get_ticks_usec()-started)/1000.0
		var complete:Array=[terrain_arrays,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,features,structures]
		if baseline.is_empty():baseline=complete
		else:check(complete==baseline,"Exact complete terrain/metadata/feature/structure outputs at both cache capacities")
		var vertices:int=0
		for arrays in structures:
			if arrays!=null:vertices+=arrays[Mesh.ARRAY_VERTEX].size()
		cases.append({"capacity":capacity,"seed":92881,"scale":.2,"tile":coordinate,"span_m":16384,"terrain_ms":terrain_ms,"features_ms":features_ms,"structures_ms":structure_ms,"structure_vertices":vertices,"height_hits":b.height_cache_hits,"height_misses":b.height_cache_misses,"height_cache_resets":b.height_cache_resets,"retained_entries":b._normal_height_cache.size(),"serialized_height_cache_bytes":var_to_bytes(b._normal_height_cache).size()})
		print("DENSE_HEIGHT_CACHE_PAIR ",cases[-1])
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable cache trial source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_dense_height_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"One serial cold pair on the actual unfinished 16km production tile at seed92881 scale0.2: exact integer-only canonical height cache capacity, complete numeric terrain/metadata/features/structures match. No geometry/view/rarity/timeout changes. Single pair is diagnostic, not sufficient evidence for production adoption or native speed claims."},"  "))
	print("DENSE_HEIGHT_CACHE_DONE failures=",failures);quit(0 if failures.is_empty() else 1)
