extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/height_cache_builder_candidate.gd","res://tools/biome_extensions/timed_dense_builder.gd","res://tools/biome_extensions/profile_dense_components.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var b=preload("res://tools/biome_extensions/timed_dense_builder.gd").new();b.settings=make_builder(7,92881).settings;b.settings.alien_infected.feature_scale=.2;b.world_seed=92881;b._configure_noise();b.chunk_size=16384;b.cache_limit=8192
	var coordinate:=Vector2i(-5,-7);b.build(coordinate,16);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();mesher.build(b,coordinate)
	b.canonical_calls=0;b.canonical_us=0;b.support_calls=0;b.support_us=0
	var start:int=Time.get_ticks_usec();var arrays:Array=Structures.new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var elapsed:int=Time.get_ticks_usec()-start
	var vertices:int=0
	for a in arrays:
		if a!=null:vertices+=a[Mesh.ARRAY_VERTEX].size()
	check(vertices==2441064,"Exact independently observed complete structure count on the failing tile")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable component profile source "+source)
	var stats:Dictionary={"elapsed_ms":elapsed/1000.0,"canonical_calls":b.canonical_calls,"canonical_ms_inclusive":b.canonical_us/1000.0,"support_calls":b.support_calls,"support_ms_inclusive":b.support_us/1000.0,"noncanonical_ms":(elapsed-b.canonical_us)/1000.0,"vertices":vertices}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_dense_components.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"stats":stats,"scope":"Single instrumented whole failing 16km tile, exact original 8192-entry normal-height capacity. Inclusive canonical/support elapsed and numerical structure work only; timer overhead is included, not an optimization or native performance certificate."},"  "))
	print("DENSE_COMPONENT_PROFILE ",stats);quit(0 if failures.is_empty() else 1)
