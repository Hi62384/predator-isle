extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/height_only_extensions_candidate.gd")
const Frozen=preload("res://tools/biome_extensions/reference_pre_height_only_builder.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/height_only_extensions_candidate.gd","res://tools/biome_extensions/reference_pre_height_only_builder.gd","res://tools/biome_extensions/profile_dense_height_only.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var live_method:String=FileAccess.get_file_as_string("res://scripts/terrain_mesh_builder.gd").get_slice("func _get_height(",1).get_slice("func _apply_coast(",0).strip_edges()
	var frozen_method:String=FileAccess.get_file_as_string("res://tools/biome_extensions/reference_pre_height_only_builder.gd").get_slice("func _get_height(",1).strip_edges()
	check(live_method==frozen_method,"Frozen reference entry point exactly reproduces current pre-adoption production method")
	var cases:Array=[];var original:Array=[]
	# Same dense tile as the preserved first-cut failure. Both use the complete
	# ORIGINAL structure producer: this isolates height publication, not LOD.
	for trial:bool in [false,true]:
		var configured=make_builder(7,92881);var b=Candidate.new() if trial else Frozen.new()
		b.settings=configured.settings;b.settings.alien_infected.feature_scale=.2;b.world_seed=92881;b._configure_noise();b.chunk_size=16384
		var coordinate:=Vector2i(-5,-7);var started:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,16);var terrain_ms:float=(Time.get_ticks_usec()-started)/1000.0
		var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();started=Time.get_ticks_usec();var features:Dictionary=mesher.build(b,coordinate);var features_ms:float=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec();var structures:Array=Structures.new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var structures_ms:float=(Time.get_ticks_usec()-started)/1000.0
		var complete:Array=[arrays,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,features,structures]
		if not trial:original=complete
		else:check(complete==original,"Complete terrain/normal/control/feature/structure attributes exactly match without publishing unused material/water controls")
		var vertices:int=0
		for attribute_array in structures:
			if attribute_array!=null:vertices+=attribute_array[Mesh.ARRAY_VERTEX].size()
		cases.append({"candidate":trial,"seed":92881,"scale":.2,"tile":coordinate,"span_m":16384,"terrain_ms":terrain_ms,"features_ms":features_ms,"structures_ms":structures_ms,"structure_vertices":vertices,"serialized_height_cache_bytes":var_to_bytes(b._normal_height_cache).size()})
		print("DENSE_HEIGHT_ONLY_PAIR ",cases[-1])
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable private height publication source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_dense_height_only.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"One serial cold full-detail dense-tile pair, same seed92881 scale0.2/tile(-5,-7) as the preserved unfinished cut. Honour extension sampler height-only requests; complete emitted terrain/normal/metadata/features/structures must remain exact. No LOD, rarity, geometry, cache capacity, worker, timeout or shader changes. Diagnostic only, not a general speed claim or production adoption."},"  "))
	quit(0 if failures.is_empty() else 1)
