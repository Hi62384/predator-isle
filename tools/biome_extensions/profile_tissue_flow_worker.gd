extends SceneTree
func _initialize()->void:
	var path:String="res://tools/biome_extensions/artifacts/render_alien_tissue_flow.json";var render=JSON.parse_string(FileAccess.get_file_as_string(path));assert(render.passed)
	var guards:Dictionary=render.source_sha256.duplicate();guards[path]=FileAccess.get_sha256(path);guards["res://tools/biome_extensions/profile_tissue_flow_worker.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/profile_tissue_flow_worker.gd")
	var selected:Array=[]
	for phase:Dictionary in render.phases:
		if phase.phase!=1:continue
		var best:Dictionary={}
		for candidate:Dictionary in phase.structure_map_cases:
			if best.is_empty() or candidate.structure_vertices<best.structure_vertices:best=candidate
		assert(not best.is_empty());selected.append({"seed":int(phase.seed),"case":best})
	var records:Array=[];var ratios:Array=[];var failures:Array=[]
	for repetition in range(3):
		for item:Dictionary in selected:
			var fixture:Dictionary=item.case;var key:=Vector3i(fixture.key[0],fixture.key[1],fixture.key[2]);var pair:Dictionary={};var outputs:Dictionary={};var added:int=0
			for enabled:bool in ([false,true] if repetition%2==0 else [true,false]):
				var b=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(item.seed,enabled);b.settings.alien_infected.emission_strength=0;b.chunk_size=256*float(1<<key.z)
				var coordinate:=Vector2i(key.x,key.y);var start:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,int(fixture.resolution));var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(b,coordinate)
				if key.z<=1 and not features.is_empty() and not features.openings.is_empty():features["ground_collision"]=preload("res://scripts/terrain_collision.gd").clipped_ground(arrays,features.openings,int(fixture.resolution))
				var steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(256,128,16,4)
				var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,steps,mesher.portal_sites)
				var emitted:int=structures[2][Mesh.ARRAY_VERTEX].size() if structures.size()>2 and structures[2]!=null else 0
				if emitted!=int(fixture.structure_vertices):failures.append("Worker fixture vertex count differs from native leaf "+str([item.seed,emitted,fixture.structure_vertices]))
				var map:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(b,structures[2],Vector2(coordinate)*b.chunk_size) if structures.size()>2 and structures[2]!=null else {}
				var collision:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,int(fixture.resolution),key.z<=1,structures,features);var water:Array=b.build_swamp_water(arrays,int(fixture.resolution))
				pair[enabled]=float(Time.get_ticks_usec()-start)/1000;outputs[enabled]=[arrays,water,features,structures,collision,b.built_extension_data.duplicate()]
				if enabled:
					if map.is_empty():failures.append("Actual selected owned structure did not build a map")
					else:added=map.data.size()+b.built_alien_tissue_flow.size()
			if outputs[false]!=outputs[true]:failures.append("Full worker geometry/water/features/structures/collision changed "+str(item.seed))
			var ratio:float=pair[true]/maxf(pair[false],.001);ratios.append(ratio);records.append({"seed":item.seed,"repetition":repetition,"key":fixture.key,"resolution":fixture.resolution,"structure_vertices_in_scene":fixture.structure_vertices,"off_ms":pair[false],"on_ms":pair[true],"ratio":ratio,"added_numeric_map_bytes":added})
	for source:String in guards:
		if FileAccess.get_sha256(source)!=guards[source]:failures.append("Changed worker cost source "+source)
	ratios.sort();var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"cases":records,"median_on_to_off_ratio":ratios[ratios.size()/2],"scope":"Nine alternating cold-builder complete worker-payload pairs at actual native-verified structure-owning leaves,three seeds. Includes terrain,features,protected openings,full structure geometry,independent full-bounds shell maps,collision preparation and water. Added sampling cost and bytes,not a speedup or isolated multithread/GPU frame-time claim. Smallest admitted owned surface per seeded scene is explicit bounded workload selection,not a worst-case performance bound."}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_tissue_flow_worker.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TISSUE_FLOW_WORKER_COST ",result.median_on_to_off_ratio," failures=",failures);quit(0 if failures.is_empty() else 1)
