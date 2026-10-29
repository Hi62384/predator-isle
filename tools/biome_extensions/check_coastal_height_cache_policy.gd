extends "res://tools/biome_extensions/check_all.gd"
const Reference=preload("res://tools/biome_extensions/height_cache_builder_candidate.gd")
const Controller=preload("res://scripts/lod_biome_extension_structures.gd")
class Synthetic:
	extends "res://scripts/terrain_mesh_builder.gd"
	var calls:int=0
	func _get_height(x:float,z:float,publish_controls:bool=true)->float:
		assert(not publish_controls)
		calls+=1
		return x*.125+z*.25
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_coastal_height_cache_policy.gd","res://tools/biome_extensions/height_cache_builder_candidate.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/alien_infected_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"]:hashes[path]=FileAccess.get_sha256(path)
	var synthetic:=Synthetic.new()
	for capacity:int in [8192,65536]:
		synthetic._normal_height_cache.clear();synthetic._normal_height_cache_capacity=capacity
		for i in range(70000):
			var x:float=i-35000;var z:float=(i%317)-158
			check(synthetic._sample_normal_height(x,z)==x*.125+z*.25,"Exact height through repeated capacity eviction")
			check(synthetic._normal_height_cache.size()<=capacity,"Declared numeric entry bound at every insertion")
		for p:Vector2 in [Vector2(.125,-.25),Vector2(2000000128,-2000000128)]:
			var size_before:int=synthetic._normal_height_cache.size();var calls_before:int=synthetic.calls
			check(synthetic._sample_normal_height(p.x,p.y)==p.x*.125+p.y*.25,"Fractional/out-of-key-range exact bypass")
			check(synthetic._normal_height_cache.size()==size_before and synthetic.calls==calls_before+1,"Bypass does not retain rounded keys")
		synthetic._height_grid_cache[Vector2i(3,-7)]=PackedFloat64Array([42.125])
		var calls_before:int=synthetic.calls
		check(synthetic._sample_normal_height(3,-7)==42.125 and synthetic.calls==calls_before,"Full payload cache remains authoritative")
		synthetic._height_grid_cache.clear()
	var policy:Array=[]
	for coastal:bool in [false,true]:
		for alien:bool in [false,true]:
			for enabled:bool in [false,true]:
				var b=make_builder(7);b.settings.rocky_coast_enabled=coastal;b.settings.beaches_enabled=coastal;b.settings.alien_infected_coverage=100 if alien else 0;b.settings.grass_coverage=0 if alien else 100;b.coastal_structure_height_cache_enabled=enabled;b._configure_noise()
				for span:float in [256,4096,8192,16384]:
					b.chunk_size=span;b._select_normal_height_cache_capacity()
					var expected:int=65536 if coastal and alien and enabled and span>=8192 else 8192
					check(b._normal_height_cache_capacity==expected,"Only coastal Alien coarse tiles use the larger budget")
					policy.append({"coastal":coastal,"alien":alien,"enabled":enabled,"span_m":span,"capacity":expected})
				b._normal_height_cache[Vector2i(5,-7)]=3.0;b._configure_noise()
				check(b._normal_height_cache.is_empty() and b._normal_height_cache_capacity==8192,"Settings reconfiguration clears and resets the worker cache")
	# An actual fine-tile transition must immediately restore the small bound.
	synthetic._coast=RefCounted.new();synthetic._extras.resize(8);synthetic._extras[7]=RefCounted.new();synthetic.chunk_size=8192;synthetic._select_normal_height_cache_capacity()
	for i in range(9000):synthetic._normal_height_cache[Vector2i(i,0)]=float(i)
	synthetic.chunk_size=256;synthetic._select_normal_height_cache_capacity()
	check(synthetic._normal_height_cache_capacity==8192 and synthetic._normal_height_cache.is_empty(),"Budget shrink evicts oversized retained data immediately")
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"));check(admission.passed,"Three actual admitted coast locations")
	var records:Array=[]
	for site:Dictionary in admission.cases:
		for mode:String in ["coastal","mixed","overlay_only"]:
			var configured=make_builder(7,int(site.seed));configured.settings.rocky_coast_enabled=true;configured.settings.beaches_enabled=true
			if mode!="coastal":configured.settings.forest_coverage=100;configured.settings.alien_infected_coverage=50 if mode=="mixed" else 0
			if mode=="overlay_only":configured.settings.alien_infected.overlay_strength=.75
			var b=Builder.new();b.settings=configured.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=int(site.seed);b._configure_noise()
			var reference=Reference.new();reference.cache_limit=8192;reference.settings=configured.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);reference.world_seed=int(site.seed);reference._configure_noise()
			for span:float in [8192,256]:
				b.chunk_size=span;reference.chunk_size=span
				var cell:=Vector2i(floori(site.position[0]/span),floori(site.position[1]/span))
				var a:Array=reference.build(cell,16);var z:Array=b.build(cell,16)
				check(a==z and reference.built_extension_data==b.built_extension_data and reference.built_extension_mask==b.built_extension_mask,"Exact complete actual coastal terrain, normal and atlas arrays")
				var old_features=preload("res://scripts/terrain_feature_meshes.gd").new();var new_features=preload("res://scripts/terrain_feature_meshes.gd").new()
				check(old_features.build(reference,cell)==new_features.build(b,cell),"Exact complete protected feature output")
				var old_emitter=Controller.new();var new_emitter=Controller.new();old_emitter.conduit_cache_enabled=false;new_emitter.conduit_cache_enabled=false
				var old_mesh:Array=old_emitter.build(reference,cell,Structures.support_grids(),old_features.portal_sites)
				var new_mesh:Array=new_emitter.build(b,cell,Structures.support_grids(),new_features.portal_sites)
				check(old_mesh==new_mesh,"Exact all-family structure positions, normals, colors and UVs")
				check(b._normal_height_cache.size()<=b._normal_height_cache_capacity,"Actual worker capacity retained")
				records.append({"seed":site.seed,"mode":mode,"span_m":span,"capacity":b._normal_height_cache_capacity,"entries":b._normal_height_cache.size(),"serialized_bytes":var_to_bytes(b._normal_height_cache).size(),"complete_output_equal":old_mesh==new_mesh and a==z})
				print("COASTAL_CACHE_POLICY_CASE ",records[-1])
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable cache-policy source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_coastal_height_cache_policy.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records,"policy":policy,"source_sha256":hashes,"production_registration":true,"scope":"Exact numeric cache eviction/bypass/full-payload precedence, 32 policy combinations, worker reconfiguration and immediate shrink bounds; eighteen actual three-seed coastal/mixed/overlay-only near/coarse complete terrain/feature/structure comparisons against the independent 8192-entry implementation. No new visual, native streaming performance, collision or cave certificate."},"  "))
	print("COASTAL_CACHE_POLICY_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
