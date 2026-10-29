extends "res://tools/biome_extensions/check_integration.gd"
const Controller=preload("res://tools/biome_extensions/instrumented_lod_structures.gd")
func strip_conduits(arrays:Array,ranges:Array[Vector2i])->Array:
	var output:Array=[];output.resize(Mesh.ARRAY_MAX)
	for attribute:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
		var values=arrays[attribute].slice(0,0);var offset:int=0
		for interval:Vector2i in ranges:values.append_array(arrays[attribute].slice(offset,interval.x));offset=interval.y
		values.append_array(arrays[attribute].slice(offset));output[attribute]=values
	return output
func emit(b,owner:Vector2i)->Dictionary:
	var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
	var g=Controller.new();var arrays:Array=g.build(b,owner,PackedFloat64Array(),guard.portal_sites)
	check(not b.has_meta(g.CONTEXT),"Transient worker LOD context removed after each build")
	return {"arrays":arrays,"ranges":g.conduit_ranges,"paths":g.path_identities,"origin":g.origin}
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	for source:String in ["res://scripts/chunk_terrain.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/instrumented_lod_structures.gd","res://tools/biome_extensions/check_runtime_structure_lod.gd","res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"]:hashes[source]=FileAccess.get_sha256(source)
	check(FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd").contains('preload("res://scripts/lod_biome_extension_structures.gd").new().build'),"Actual production worker registers the controller, not a test-side visible replacement")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"));check(manifest.passed,"Actual default-rarity custom sites")
	var cases:Array=[];var reductions:int=0
	for item:Dictionary in manifest.cases:
		if float(item.feature_scale)!=.2:continue
		var p:=Vector2(item.position[0],item.position[1]);var b=make_builder(7,int(item.seed));b.settings.alien_infected.feature_scale=.2;b._configure_noise();b.chunk_size=4096
		var owner:=Vector2i(floori(p.x/4096),floori(p.y/4096));var enabled:Dictionary=emit(b,owner)
		b.settings.alien_infected.hive_structure_lod_enabled=false;var zero:Dictionary=emit(b,owner);var full:Array=build_structures(b,owner)
		check(zero.arrays==full,"Complete disabled controller arrays equal the original full-detail producer")
		check(zero.paths==enabled.paths,"Enable/disable preserves every canonical conduit identity and ordering")
		var original_landmarks:Array=strip_conduits(full[2],zero.ranges);var enabled_landmarks:Array=strip_conduits(enabled.arrays[2],enabled.ranges)
		check(original_landmarks==enabled_landmarks,"Every complete landmark attribute remains exact through actual LOD enable/disable")
		var old_count:int=full[2][Mesh.ARRAY_VERTEX].size();var new_count:int=enabled.arrays[2][Mesh.ARRAY_VERTEX].size()
		if new_count<old_count:reductions+=1
		check(new_count<=old_count,"No hidden extra geometry in the reduced-detail path")
		b.settings.alien_infected.hive_structure_lod_enabled=true;b.chunk_size=2048;var child_paths:Array[String]=[];var child_landmarks:Array[String]=[]
		for z in range(2):
			for x in range(2):
				var child:Dictionary=emit(b,owner*2+Vector2i(x,z));child_paths.append_array(child.paths)
				if child.arrays[2]!=null:child_landmarks.append_array(world_vertices([strip_conduits(child.arrays[2],child.ranges)],child.origin))
		var parent_paths:Array[String]=enabled.paths.duplicate();parent_paths.sort();child_paths.sort();check(parent_paths==child_paths,"One canonical conduit identity across the parent/four-child detail transition, none omitted/duplicated")
		var parent_landmarks:Array[String]=world_vertices([enabled_landmarks],enabled.origin);parent_landmarks.sort();child_landmarks.sort();check(parent_landmarks==child_landmarks,"Every complete landmark world vertex survives parent/four-child cuts")
		cases.append({"seed":item.seed,"scale":.2,"span_m":4096,"original_vertices":old_count,"lod_vertices":new_count,"conduits":enabled.paths.size(),"landmark_vertices":enabled_landmarks[Mesh.ARRAY_VERTEX].size()})
	check(cases.size()==3 and reductions>0,"All three actual seeded sites, including real medium-detail reduction")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable runtime LOD source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_runtime_structure_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":true,"scope":"Actual worker controller registration plus complete zero-mode/full-producer equality, complete landmark attribute retention and stable conduit identities/landmark world vertices across parent/four-child detail changes at three normal-rarity minimum-scale sites. Near geometry/cached profile equality and native streaming/return/render proofs are separate. Mixed/coastal/noise retained-contact topology and registered worker behavior are tested separately."},"  "))
	print("RUNTIME_STRUCTURE_LOD_CHECK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
