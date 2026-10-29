extends "res://tools/biome_extensions/check_production_nerve_fibres.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/check_production_nerve_fibres.gd","res://tools/biome_extensions/profile_nerve_fibres.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var ratios:Array=[];var changed_vertices:int=0
	for seed_id:int in [73921,17,92881]:
		for repeat in range(3):
			var pair:Dictionary={};var outputs:Dictionary={}
			for strength:float in ([0,24] if repeat%2==0 else [24,0]):
				var b=field_builder(seed_id,1,strength);b.chunk_size=2048
				var started:int=Time.get_ticks_usec();var arrays:Array=b.build(Vector2i(5,-1),64);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
				# GDScript Dictionary preserves float versus integer key types.
				# Use one explicit key type for insertion and paired lookup.
				outputs[int(strength)]=arrays;pair[int(strength)]=elapsed
				var nerve_nodes:int=0
				for value:PackedFloat64Array in b._extras[7]._nodes.values():
					if value[3]>.2 and value[3]<.4:nerve_nodes+=1
				records.append({"seed":seed_id,"repeat":repeat,"strength_m":strength,"numeric_terrain_ms":elapsed,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"indices":arrays[Mesh.ARRAY_INDEX].size(),"field_cache_nodes":b._extras[7]._nodes.size(),"nerve_region_nodes_retained":nerve_nodes,"private_frame_points_retained":1 if not b._extras[7]._last_frame.is_empty() else 0,"atlas_bytes":b.built_extension_data.size()})
			check(outputs[0][Mesh.ARRAY_VERTEX].size()==outputs[24][Mesh.ARRAY_VERTEX].size() and outputs[0][Mesh.ARRAY_INDEX]==outputs[24][Mesh.ARRAY_INDEX],"Relief does not add tessellation or triangles")
			for i in range(outputs[0][Mesh.ARRAY_VERTEX].size()):
				if outputs[0][Mesh.ARRAY_VERTEX][i].y!=outputs[24][Mesh.ARRAY_VERTEX][i].y:changed_vertices+=1
			ratios.append(pair[24]/maxf(pair[0],.001))
	ratios.sort();check(changed_vertices>100,"Benchmark exercises actual physical changes")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable numeric profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_nerve_fibres.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"paired_median_numeric_terrain_ratio":ratios[ratios.size()/2],"changed_vertices_across_pairs":changed_vertices,"source_sha256":hashes,"scope":"Nine serial alternating cold-builder off/default pairs over three seeds, actual 2048m/64-resolution terrain and atlas construction at signed cell (5,-1). Measures added canonical-field CPU cost only, not a speed improvement, actual worker scheduling, cold process launch, physics or GPU/uninterrupted streaming."},"  "))
	print("NERVE_FIBRES_PROFILE ",checks," failures=",failures," numeric_ratio=",ratios[ratios.size()/2]);quit(0 if failures.is_empty() else 1)
