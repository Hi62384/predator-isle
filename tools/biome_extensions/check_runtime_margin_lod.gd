extends "res://tools/biome_extensions/profile_margin_retaining_lod.gd"
class ActualInstrumented:
	extends "res://scripts/lod_biome_extension_structures.gd"
	var conduit_ranges:Array[Vector2i]=[]
	var identities:Array[String]=[]
	func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
		var first:int=vertices.size();identities.append(var_to_bytes([a,b,width,phase,color]).hex_encode());super.conduit(builder,a,b,width,phase,color);conduit_ranges.append(Vector2i(first,vertices.size()))
func configured(seed_id:int,mode:String):
	var b=make_builder(7,seed_id)
	if mode=="mixed":b.settings.alien_infected.feature_scale=.2;b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50
	else:b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
	b._configure_noise();return b
func emit_node(b,g,coordinate:Vector2i)->Dictionary:
	var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.builder=b
	var arrays:Array=g.build(b,coordinate,Structures.support_grids(),features.portal_sites)
	return {"arrays":arrays,"ranges":g.conduit_ranges,"identities":g.identities,"origin":g.origin}
func landmark_world(result:Dictionary)->Array[String]:
	var values:Array[String]=[]
	if result.arrays[2]==null:return values
	for p:Vector3 in landmarks(result.arrays[2],result.ranges)[0]:values.append(var_to_bytes(p+result.origin).hex_encode())
	values.sort();return values
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/check_runtime_margin_lod.gd","res://tools/biome_extensions/profile_margin_retaining_lod.gd","res://tools/biome_extensions/profile_far_conduit_lod.gd","res://tools/biome_extensions/reference_lod_full_structures.gd","res://tools/biome_extensions/margin_retaining_lod_candidate.gd","res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json","res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"]:hashes[path]=FileAccess.get_sha256(path)
	var shore=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"));check(shore.passed,"Actual shore-site admission")
	var cases:Array=[];var reduced:int=0
	for seed_id:int in [73921,17,92881]:
		for mode:String in ["mixed","shore"]:
			var b=configured(seed_id,mode);var size:int=4096 if mode=="mixed" else 16384;var owner:=Vector2i.ZERO
			if mode=="mixed":owner=locate_mixed_tile(b,seed_id)
			else:
				for site:Dictionary in shore.cases:
					if int(site.seed)==seed_id:owner=Vector2i(floori(float(site.position[0])/size),floori(float(site.position[1])/size))
			b.chunk_size=size;var actual:Dictionary=emit_node(b,ActualInstrumented.new(),owner);var expected:Dictionary=emit_node(b,TrialInstrumented.new(),owner)
			check(actual.arrays==expected.arrays,"Complete registered cold/warm whole-node arrays match independent private emitter")
			check(actual.identities==expected.identities and not actual.identities.is_empty(),"All actual normal-rarity conduit identities/counts retained")
			b.settings.alien_infected.hive_structure_lod_enabled=false;var disabled:Dictionary=emit_node(b,ActualInstrumented.new(),owner);var full:Dictionary=emit_node(b,FullInstrumented.new(),owner)
			check(disabled.arrays==full.arrays,"Complete independent disabled-node arrays equal original full producer")
			check(landmarks(actual.arrays[2],actual.ranges)==landmarks(full.arrays[2],full.ranges),"Every non-conduit landmark attribute unchanged")
			var before:int=full.arrays[2][Mesh.ARRAY_VERTEX].size();var after:int=actual.arrays[2][Mesh.ARRAY_VERTEX].size();check(after<=before,"Actual whole-node geometry does not increase")
			if after<before:reduced+=1
			b.settings.alien_infected.hive_structure_lod_enabled=true;b.chunk_size=size/2;var children_ids:Array[String]=[];var children_landmarks:Array[String]=[]
			for z in range(2):
				for x in range(2):
					var child:Dictionary=emit_node(b,ActualInstrumented.new(),owner*2+Vector2i(x,z));children_ids.append_array(child.identities);children_landmarks.append_array(landmark_world(child))
			var parent_ids:Array[String]=actual.identities.duplicate();parent_ids.sort();children_ids.sort();check(parent_ids==children_ids,"Exact parent/four-child root identities, none omitted or duplicated")
			children_landmarks.sort();check(landmark_world(actual)==children_landmarks,"All complete landmark world vertices stable across the actual parent/child detail transition")
			cases.append({"seed":seed_id,"mode":mode,"span_m":size,"tile":owner,"conduits":actual.identities.size(),"original_vertices":before,"registered_vertices":after,"landmark_vertices":landmarks(actual.arrays[2],actual.ranges)[0].size()})
	check(cases.size()==6 and reduced>=3,"All three seeded mixed and actual-shore owner cases, including real complete-node reductions")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable registered whole-node LOD source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_runtime_margin_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":true,"scope":"Six complete registered mixed/shore owner cases: independent private-emitter full array equivalence, complete disabled/original arrays, all landmark attributes and parent/four-child root/world-landmark identity. Bounded cache enabled in actual controller versus uncached independent emitters. Shore coordinates come from actual coastal deformation, no forced rarity. Threaded native rendering, arbitrary settings and uninterrupted performance remain separate."},"  "))
	print("RUNTIME_MARGIN_LOD ",checks," cases=",cases," failures=",failures);quit(0 if failures.is_empty() else 1)
