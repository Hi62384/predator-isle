extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const Structures=preload("res://scripts/biome_extension_structures.gd")
func build_structures(b,coordinate:Vector2i)->Array:
	var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
	return Structures.new().build(b,coordinate,PackedFloat64Array(),guard.portal_sites)
var checks:int=0
var failures:Array=[]
var report:Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func make_builder(index:int,seed_id:int=73921):
	var b=Builder.new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for k:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(k+"_coverage",0)
	b.settings.set(TerrainSettings.EXTENSION_KEYS[index]+"_coverage",100);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b._configure_noise();return b
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/biome_extensions/artifacts"))
	for family_id in range(8):
		var start:int=Time.get_ticks_usec();var b=make_builder(family_id);var sampler=b._extras[family_id];var records:Array=[];var sites:Dictionary={}
		for i in range(130):
			var p:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
			var h:float=b._get_height(p.x,p.y);var payload:PackedVector4Array=b._last_extras
			check(is_finite(h) and is_finite(b._last_swamp_water),"Finite "+str(family_id));check(h==b._get_height(p.x,p.y,false),"Height-only "+str(family_id));records.append([p,h,payload])
			if b._island_mask(p.x,p.y)>.03:
				var description:Dictionary=sampler.describe(p);var id:int=clampi(roundi(description.region),0,5)
				if not sites.has(str(id)):sites[str(id)]={"x":p.x,"z":p.y,"descriptor":description}
		sampler._nodes.clear();sampler._descriptors.clear();records.reverse()
		for record:Array in records:
			check(record[1]==b._get_height(record[0].x,record[0].y),"Order independent "+str(family_id));check(record[2]==b._last_extras,"Payload order "+str(family_id))
		for x:float in [-32,0,16,256]:
			var h:float=sampler.sample(x,0);var dl:float=(h-sampler.sample(x-.01,0))/.01;var dr:float=(sampler.sample(x+.01,0)-h)/.01
			check(absf(dl-dr)<.05,"C1 "+str(family_id))
		var a:Array=b.build(Vector2i(20,20),16);var data:PackedByteArray=b.built_extension_data;var right:Array=b.build(Vector2i(21,20),16);var rd:PackedByteArray=b.built_extension_data
		for z in range(17):
			var i:int=z*17+16;var j:int=z*17
			check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent height "+str(family_id));check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent normal "+str(family_id));check(a[Mesh.ARRAY_TEX_UV][i].x==right[Mesh.ARRAY_TEX_UV][j].x,"Adjacent water "+str(family_id))
			if not data.is_empty() and not rd.is_empty():
				for k in range(32):
					var f:int=k/4;var channel:int=k%4
					check(data[(z*17*8+f*17+16)*4+channel]==rd[(z*17*8+f*17)*4+channel],"Adjacent metadata "+str(family_id))
		b.chunk_size=512;var parent:Array=b.build(Vector2i(10,10),16);b.chunk_size=256;var child:Array=b.build(Vector2i(20,20),16)
		for z in range(9):
			for x in range(9):check(parent[Mesh.ARRAY_VERTEX][z*17+x].y==child[Mesh.ARRAY_VERTEX][z*2*17+x*2].y,"LOD height "+str(family_id))
		check(sampler._nodes.size()<=8192 and sampler._descriptors.size()<=512,"Bounded "+str(family_id))
		var batch_start:int=Time.get_ticks_usec();b.chunk_size=2048;var mesh:Array=b.build(Vector2i(2,2),32);var build_ms:float=(Time.get_ticks_usec()-batch_start)/1000.0
		var structure_start:int=Time.get_ticks_usec();var geometry:Array=build_structures(b,Vector2i(2,2));var triangles:int=0
		for arrays in geometry:
			if arrays==null:continue
			triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3
			for v:Vector3 in arrays[Mesh.ARRAY_NORMAL]:check(v.is_finite() and v.length_squared()>.9,"Structure normal "+str(family_id))
		report[TerrainSettings.EXTENSION_KEYS[family_id]]={"sample_and_test_ms":(Time.get_ticks_usec()-start)/1000.0,"mesh_2048m_32_resolution_ms":build_ms,"structure_ms":(Time.get_ticks_usec()-structure_start)/1000.0,"triangles":triangles,"preview_regions":sites,"metadata_bytes":b.built_extension_data.size()}
		print("EXTENSION_TEST ",TerrainSettings.EXTENSION_KEYS[family_id]," ",build_ms," ms ",triangles," structure triangles")
	# All owners coexist in the existing hierarchy; no new competitor overlays.
	var mixed=make_builder(0)
	for k:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:mixed.settings.set(k+"_coverage",20)
	mixed._configure_noise()
	for i in range(1000):
		var w:Vector4=mixed._biome_weights(i*7919%1000000-500000,i*11939%1000000-500000);var total:float=w.x+w.y+w.z+w.w+mixed._jungle_weight+mixed._mountain_weight+mixed._tropical_weight+mixed._badlands_weight
		for v:float in mixed._extra_weights:total+=v
		check(absf(total-1)<.00001,"Sixteen-owner normalization")
	# Zero extension coverage must preserve old complete mesh payloads exactly.
	var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://data/pre_badlands_mesh_hashes.json"))
	for record:Dictionary in baseline.records:
		var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.badlands_coverage=0
		if record.preset!="saved_world":
			for k:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(k+"_coverage",0)
			b.settings.beaches_enabled=record.preset=="coast";b.settings.rocky_coast_enabled=record.preset=="coast";b.settings.tropical_coverage=100 if record.preset!="mountain" else 0
			if record.preset=="mountain":b.settings.mountain_coverage=100
			if record.preset=="mixed_tropical":b.settings.forest_coverage=50;b.settings.forest_region_size=14000
		b._configure_noise();var mesh:Array=b.build(Vector2i(record.cell[0],record.cell[1]),16)
		for channel in range(Mesh.ARRAY_MAX):
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(mesh[channel]));check(hash.finish().hex_encode()==record.hashes[channel],"Old exact payload "+str(channel))
		check(b.built_extension_data.is_empty(),"Zero allocation for disabled extensions")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_all.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"families":report},"\t"))
	print("EXTENSION_RESULT ",checks," checks; ",failures.size()," failures ",failures);quit(0 if failures.is_empty() else 1)
