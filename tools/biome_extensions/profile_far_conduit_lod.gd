extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/far_conduit_lod_candidate.gd")
const Full=preload("res://tools/biome_extensions/reference_lod_full_structures.gd")
func landmarks(arrays:Array,ranges:Array[Vector2i])->Array:
	var result:Array=[]
	for attribute:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
		var values=arrays[attribute].slice(0,0);var offset:int=0
		for interval:Vector2i in ranges:values.append_array(arrays[attribute].slice(offset,interval.x));offset=interval.y
		values.append_array(arrays[attribute].slice(offset));result.append(values)
	return result
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/far_conduit_lod_candidate.gd","res://tools/biome_extensions/reference_lod_full_structures.gd","res://tools/biome_extensions/profile_far_conduit_lod.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[];var original_landmarks:Array=[];var original_fields:Array=[];var original_count:int=0
	for candidate:bool in [false,true]:
		var b=make_builder(7,92881);b.settings.alien_infected.feature_scale=.2;b._configure_noise();b.chunk_size=16384;var coordinate:=Vector2i(-5,-7)
		var terrain_arrays:Array=b.build(coordinate,16);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(b,coordinate)
		var fields:Array=[terrain_arrays,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,features]
		var g=Candidate.new() if candidate else Full.new();var started:int=Time.get_ticks_usec();var arrays:Array=g.build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
		var retained:Array=landmarks(arrays[2],g.conduit_ranges)
		if not candidate:original_landmarks=retained;original_fields=fields;original_count=g.conduit_ranges.size()
		else:
			check(retained==original_landmarks,"Every complete non-conduit landmark vertex/normal/color/UV retained exactly")
			check(fields==original_fields,"Complete terrain/normal/atlas/water/finite-feature outputs remain exact")
			check(g.conduit_ranges.size()==original_count,"Every original conduit remains present once")
		cases.append({"candidate":candidate,"seed":92881,"scale":.2,"tile":coordinate,"span_m":16384,"structures_ms":elapsed,"vertices":arrays[2][Mesh.ARRAY_VERTEX].size(),"conduits":g.conduit_ranges.size(),"non_conduit_landmark_vertices":retained[0].size(),"detail_counts":g.detail_counts if candidate else {1:g.conduit_ranges.size()}})
		print("FAR_CONDUIT_LOD_PAIR ",cases[-1])
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable full-tile LOD trial source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_far_conduit_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"One serial cold original/private-LOD pair on the actual unfinished 16km tile, seed92881 scale0.2. All original conduits retained once, complete non-conduit landmark arrays and all terrain/metadata/finite-feature outputs exact. Original near field and supported pure-Alien conservative distant foundations. Single pair is diagnostic, not a general/native speed or visual/collision certificate."},"  "))
	print("FAR_CONDUIT_LOD_PROFILE_DONE failures=",failures);quit(0 if failures.is_empty() else 1)
