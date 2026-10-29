extends "res://tools/biome_extensions/check_integration.gd"
const Before=preload("res://tools/biome_extensions/reference_pre_membrane_structures.gd")
const Trial=preload("res://tools/biome_extensions/surface_guided_complex_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/surface_guided_complex_candidate.gd","res://tools/biome_extensions/surface_guided_junction_candidate.gd","res://tools/biome_extensions/surface_guided_membrane_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/reference_pre_membrane_structures.gd","res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://tools/biome_extensions/membrane_junction_candidate.gd","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/check_integration.gd","res://tools/biome_extensions/check_production_membranes.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admission.passed,"Current default production sites")
	var cases:Array=[];var default_membranes:int=0
	for item:Dictionary in admission.cases:
		var b=make_builder(7,int(item.seed));b.settings.alien_infected.conduit_cache_mib=0;b._configure_noise();var p:=Vector2(item.position[0],item.position[1]);var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
		var actual:Array=build_structures(b,coordinate)
		b.settings.alien_infected.hive_membrane_frequency=0;var bare:Array=build_structures(b,coordinate)
		b.settings.alien_infected.hive_membrane_frequency=1;var full:Array=build_structures(b,coordinate)
		check(bare[2]!=null and full[2]!=null,"Real full-weight dry junction with ordinary cavity guards")
		if bare[2]==null or full[2]==null:continue
		var prefix:int=bare[2][Mesh.ARRAY_VERTEX].size();check(full[2][Mesh.ARRAY_VERTEX].size()-prefix==5136,"Independent membrane toggle adds exactly one complete closed volume")
		for attribute:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:check(full[2][attribute].slice(0,prefix)==bare[2][attribute],"Membrane does not rewrite original conduit/blade/strut arrays")
		var member:bool=b._extras[7].random(cell.x,cell.y,248)<.4
		check(actual==(full if member else bare),"Actual default .4 rarity chooses the exact forced-on/off geometry")
		if member:default_membranes+=1
		var field=b._extras[7];var edges:PackedVector2Array=field.network_edges(cell);var descriptor:Dictionary=field.descriptor(cell,4096);var directions:Array[Vector2]=[(edges[1]-p).normalized(),(edges[5]-p).normalized()]
		var g=Structures.new();g.origin=Vector3(coordinate.x*256,0,coordinate.y*256);g._support_steps=Structures.support_grids();Trial.new().emit(g,b,p,directions,item.width,item.junction_height,descriptor.angle)
		var network_prefix:int=prefix-9168
		for pair:Array in [[Mesh.ARRAY_VERTEX,g.vertices],[Mesh.ARRAY_NORMAL,g.normals],[Mesh.ARRAY_COLOR,g.colors],[Mesh.ARRAY_TEX_UV,g.uvs]]:check(full[2][pair[0]].slice(network_prefix)==pair[1],"Complete production junction/membrane tail equals the preserved independent trial")
		# All three morphology controls disabled reproduce the pinned baseline
		# producer, not just a count or a hand-built primitive.
		b.settings.alien_infected.hive_membrane_frequency=0;b.settings.alien_infected.hive_longitudinal_ribs=false;b.settings.alien_infected.hive_surface_guided_roots=false
		for size:int in [256,2048,4096]:
			b.chunk_size=size;var owner:=Vector2i(floori(p.x/size),floori(p.y/size));var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
			check(Structures.new().build(b,owner,PackedFloat64Array(),guard.portal_sites)==Before.new().build(b,owner,PackedFloat64Array(),guard.portal_sites),"Exact complete pre-integration arrays with all three morphology controls disabled")
		b.settings.alien_infected.hive_membrane_frequency=1;b.settings.alien_infected.hive_longitudinal_ribs=true;b.settings.alien_infected.hive_surface_guided_roots=true;b.chunk_size=4096
		var parent_cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var parent:Array=build_structures(b,parent_cell);var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*4096,0,parent_cell.y*4096));var children:Array[String]=[];b.chunk_size=2048
		for z in range(2):
			for x in range(2):
				var owner:Vector2i=parent_cell*2+Vector2i(x,z);children.append_array(world_vertices(build_structures(b,owner),Vector3(owner.x*2048,0,owner.y*2048)))
		expected.sort();children.sort();check(expected==children,"One stable full membrane/junction owner through parent/four-child cut")
		cases.append({"seed":item.seed,"position":p,"default_membrane_present":member,"membrane_vertices_added":5136,"full_junction_vertices":14304,"complete_zero_reference_sizes_m":[256,2048,4096],"normal_cavity_guards":true})
	check(default_membranes>0,"At least one actual default-rarity membrane, not only forced fixtures")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable production membrane source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_production_membranes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Actual production normal-guard membrane admission, independent default/zero/full conditional rarity, unchanged complete prefixes, exact preserved-trial full tail, complete frozen pre-integration arrays when both controls are disabled and stable signed parent/four-child ownership at three real seeded roots. Native streamed geometry/collision/return walks and performance are separate."},"  "))
	print("PRODUCTION_MEMBRANES ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
