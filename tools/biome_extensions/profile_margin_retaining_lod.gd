extends "res://tools/biome_extensions/profile_far_conduit_lod.gd"
class FullInstrumented:
	extends "res://tools/biome_extensions/reference_lod_full_structures.gd"
	var identities:Array[String]=[]
	func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
		identities.append(var_to_bytes([a,b,width,phase,color]).hex_encode());super.conduit(builder,a,b,width,phase,color)
class TrialInstrumented:
	extends "res://tools/biome_extensions/margin_retaining_lod_candidate.gd"
	var conduit_ranges:Array[Vector2i]=[]
	var identities:Array[String]=[]
	func _init()->void:conduit_cache_enabled=false
	func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
		identities.append(var_to_bytes([a,b,width,phase,color]).hex_encode());super.conduit(builder,a,b,width,phase,color)
	func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
		var first:int=vertices.size();super._conduit_uncached(builder,a,b,width,phase,color);conduit_ranges.append(Vector2i(first,vertices.size()))
func locate_mixed_tile(b,seed_id:int)->Vector2i:
	var sites=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"));var p:=Vector2.INF
	for site:Dictionary in sites.cases:
		if int(site.seed)==seed_id and site.feature_scale==.2:p=Vector2(site.position[0],site.position[1])
	check(p.is_finite(),"Actual seeded land landmark for mixed-site discovery")
	var field=b._extras[7];var span:float=4096*.2;var center:=Vector2i(floori(p.x/span),floori(p.y/span))
	for z in range(-24,25):
		for x in range(-24,25):
			var cell:=center+Vector2i(x,z);var a:Vector2=field.hive_node(cell);b._biome_weights(a.x,a.y)
			var d:Dictionary=field.descriptor(cell,span)
			if b._extra_weights[7]<.55 or b._island_mask(a.x,a.y)<.03 or d.chance>field.settings.structure_density:continue
			if b._get_height(a.x,a.y)<b.get_water_surface_height(a.x,a.y)+2:continue
			return Vector2i(floori(a.x/4096),floori(a.y/4096))
	check(false,"Normal-rarity mixed-world conduit owner must be found, not skipped");return Vector2i.ZERO
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/profile_far_conduit_lod.gd","res://tools/biome_extensions/reference_lod_full_structures.gd","res://tools/biome_extensions/margin_retaining_lod_candidate.gd","res://tools/biome_extensions/profile_margin_retaining_lod.gd","res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var reductions:int=0
	for fixture:int in range(4):
		var seed_id:int=[92881,73921,17,92881][fixture];var mode:String="coastal_dense" if fixture==0 else "mixed";var size:int=16384 if fixture==0 else 4096
		var coordinate:=Vector2i(-5,-7)
		if fixture>0:
			var finder=make_builder(7,seed_id);finder.settings.alien_infected.feature_scale=.2;finder.settings.forest_coverage=100;finder.settings.alien_infected_coverage=50;finder._configure_noise();coordinate=locate_mixed_tile(finder,seed_id)
		var pair:Dictionary={}
		var order:Array=[true,false] if fixture%2==0 else [false,true]
		for trial:bool in order:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=.2
			if fixture==0:b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
			else:b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50
			b._configure_noise();b.chunk_size=size
			var fields:Array=b.build(coordinate,16);var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(b,coordinate)
			var g=TrialInstrumented.new() if trial else FullInstrumented.new();var started:int=Time.get_ticks_usec();var arrays:Array=g.build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
			check(arrays[2]!=null and not g.identities.is_empty(),"Actual normal-rarity complete tile contains conduits, no empty performance sample")
			if arrays[2]==null:continue
			pair[trial]={"fields":[fields,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,features],"landmarks":landmarks(arrays[2],g.conduit_ranges),"identities":g.identities,"vertices":arrays[2][Mesh.ARRAY_VERTEX].size(),"elapsed_ms":elapsed,"conduits":g.conduit_ranges.size()}
			print("MARGIN_LOD_TILE ",mode," seed=",seed_id," trial=",trial," ms=",elapsed," vertices=",pair[trial].vertices," conduits=",g.conduit_ranges.size())
		check(pair.has(false) and pair.has(true),"Both complete tile pair members required")
		if not pair.has(false) or not pair.has(true):continue
		check(pair[false].fields==pair[true].fields,"Complete canonical terrain/normal/atlas/finite-feature outputs unchanged")
		check(pair[false].landmarks==pair[true].landmarks,"Every non-conduit landmark vertex/normal/colour/UV unchanged")
		check(pair[false].identities==pair[true].identities and pair[false].conduits==pair[true].conduits,"Every normal-rarity conduit identity, order and multiplicity retained")
		check(pair[true].vertices<pair[false].vertices,"Actual complete unsupported-host tile simplifies, not just an isolated primitive")
		if pair[true].vertices<pair[false].vertices:reductions+=1
		cases.append({"seed":seed_id,"mode":mode,"tile":coordinate,"span_m":size,"original_ms":pair[false].elapsed_ms,"trial_ms":pair[true].elapsed_ms,"original_vertices":pair[false].vertices,"trial_vertices":pair[true].vertices,"conduits":pair[true].conduits,"unchanged_landmark_vertices":pair[true].landmarks[0].size()})
	check(cases.size()==4 and reductions==4,"All declared coast-enabled dense and three seeded mixed tile pairs")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable whole-tile private LOD source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_margin_retaining_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_registration":false,"scope":"Four serial cold original/private whole-tile pairs with alternating order: unchanged dense seed92881 coast-enabled 16km tile and normal-rarity mixed-owner 4km tiles over three seeds. Exact all canonical terrain/normal/metadata/finite-feature and landmark attributes; complete conduit identities/counts retained. Both use disabled numeric mesh memo to isolate tessellation. Single pair per fixture, not native streaming, general speed, shader or visual acceptance."},"  "))
	print("MARGIN_LOD_TILE_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
