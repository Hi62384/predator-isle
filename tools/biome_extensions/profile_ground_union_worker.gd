extends SceneTree
const Candidate=preload("res://tools/biome_extensions/conduit_ground_union_candidate.gd")
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/render_alien_tissue_flow.json.txt"
func _initialize()->void:
	var frozen=JSON.parse_string(FileAccess.get_file_as_string(FROZEN));assert(frozen.passed);var guards:Dictionary={FROZEN:FileAccess.get_sha256(FROZEN)};var selected:Array=[]
	for phase:Dictionary in frozen.phases:
		if phase.phase!=1:continue
		var best:Dictionary={}
		for fixture:Dictionary in phase.structure_map_cases:
			if best.is_empty() or fixture.structure_vertices<best.structure_vertices:best=fixture
		assert(not best.is_empty());selected.append({"seed":int(phase.seed),"case":best})
	assert(selected.size()==3)
	for path:String in [Candidate.SOURCE,Candidate.BASE,"res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://scripts/alien_tissue_coordinates.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://tools/biome_extensions/profile_ground_union_worker.gd"]:guards[path]=FileAccess.get_sha256(path)
	var prototype:GDScript=Candidate.script_for();var records:Array=[];var ratios:Array=[];var failures:Array=[]
	for repetition in range(3):
		for item:Dictionary in selected:
			var fixture:Dictionary=item.case;var key:=Vector3i(fixture.key[0],fixture.key[1],fixture.key[2]);var times:Dictionary={};var outputs:Dictionary={}
			for enabled:bool in ([false,true] if repetition%2==0 else [true,false]):
				var builder=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(item.seed,true);builder.settings.alien_infected.emission_strength=0;builder.chunk_size=256*float(1<<key.z);var coordinate:=Vector2i(key.x,key.y);var resolution:int=int(fixture.resolution)
				var started:int=Time.get_ticks_usec();var arrays:Array=builder.build(coordinate,resolution);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(builder,coordinate)
				if key.z<=1 and not features.is_empty() and not features.openings.is_empty():features["ground_collision"]=preload("res://scripts/terrain_collision.gd").clipped_ground(arrays,features.openings,resolution)
				var steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(256,128,16,4);var generator=prototype.new() if enabled else preload("res://scripts/lod_biome_extension_structures.gd").new();var structures:Array=generator.build(builder,coordinate,steps,mesher.portal_sites)
				var map:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(builder,structures[2],Vector2(coordinate)*builder.chunk_size);var collision:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,resolution,key.z<=1,structures,features);var water:Array=builder.build_swamp_water(arrays,resolution);times[enabled]=(Time.get_ticks_usec()-started)/1000.0
				if structures[2][Mesh.ARRAY_VERTEX].size()!=int(fixture.structure_vertices):failures.append("Actual native-owned root vertex count changed "+str(item.seed))
				outputs[enabled]={"arrays":arrays,"features":features,"water":water,"structures":structures,"map":map,"collision":collision,"packed":builder.built_extension_data.duplicate(),"flow":builder.built_alien_tissue_flow.duplicate()}
			var old:Dictionary=outputs[false];var current:Dictionary=outputs[true]
			for field:String in ["arrays","features","water","map","packed","flow"]:
				if old[field]!=current[field]:failures.append("Non-structure worker payload changed "+str([item.seed,field]))
			for field:String in old.collision:
				if field!="structure_faces" and old.collision[field]!=current.collision[field]:failures.append("Non-structure collision field changed "+field)
			if old.structures[0]!=current.structures[0] or old.structures[1]!=current.structures[1]:failures.append("Unrelated structure family changed")
			var a:PackedVector3Array=old.structures[2][Mesh.ARRAY_VERTEX];var b:PackedVector3Array=current.structures[2][Mesh.ARRAY_VERTEX];var changed:int=0
			for index in range(a.size()):
				if a[index].x!=b[index].x or a[index].z!=b[index].z:failures.append("Horizontal support changed")
				if a[index]!=b[index]:changed+=1
			if changed==0:failures.append("Actual native-owned root did not exercise the proposed shoulder "+str(item.seed))
			if old.structures[2][Mesh.ARRAY_COLOR]!=current.structures[2][Mesh.ARRAY_COLOR] or old.structures[2][Mesh.ARRAY_TEX_UV]!=current.structures[2][Mesh.ARRAY_TEX_UV]:failures.append("Semantic controls changed")
			if current.collision.structure_faces!=b:failures.append("Candidate collision does not use complete actual new root vertices")
			var ratio:float=times[true]/maxf(times[false],.001);ratios.append(ratio);records.append({"seed":item.seed,"repetition":repetition,"key":fixture.key,"resolution":int(fixture.resolution),"vertices":a.size(),"changed_vertices":changed,"original_ms":times[false],"candidate_ms":times[true],"ratio":ratio})
	for path:String in guards:
		if FileAccess.get_sha256(path)!=guards[path]:failures.append("Source changed "+path)
	ratios.sort();FileAccess.open("res://tools/biome_extensions/artifacts/profile_ground_union_worker.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"cases":records,"median_candidate_to_original_ratio":ratios[ratios.size()/2],"scope":"PRIVATE nine alternating cold full-worker payload pairs at the SAME three original native-verified smallest admitted owned roots,not a worst-case sample. Actual production builder/class-sensitive bounds,terrain,features,portal protection,structures,whole-shell path maps,collision and water. Proposed change must alter actual structure Y/normals and matching complete collision faces,while preserving all non-structure payloads,atlas bytes,vertex counts,XZ and semantic controls exactly. Timings include added per-profile ground queries;not multithreaded streaming,frame-time,universal speedup or production acceptance."},"  "));print("GROUND_UNION_WORKER_COST ",ratios[ratios.size()/2]," failures=",failures);quit(0 if failures.is_empty() else 1)
