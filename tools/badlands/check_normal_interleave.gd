extends SceneTree
## Independent paired output check, including mixed-owner metadata and water.
func builder_for(seed_id:int,mode:String,span:float):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new()
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	b.world_seed=seed_id;b.chunk_size=span
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.badlands_coverage=100 if mode=="badlands" else (50 if mode=="mixed" else 0)
	b.settings.quarry_coverage=100-b.settings.badlands_coverage
	b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b._configure_noise()
	return b
func locate(b,mode:String)->Vector2:
	for i in range(4000):
		var p:=Vector2(i*7919%180000-90000,i*11939%180000-90000)
		if b._island_mask(p.x,p.y)<.2:continue
		b._biome_weights(p.x,p.y)
		if mode!="mixed" or (b._badlands_weight>.1 and b._extra_weights[0]>.1):return p
	assert(false,"Inland fixture not found");return Vector2.ZERO
func digest(b,arrays:Array,resolution:int)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for data in arrays:context.update(var_to_bytes(data))
	context.update(var_to_bytes(b.built_extension_data))
	context.update(var_to_bytes(b.built_extension_mask))
	context.update(var_to_bytes(b.built_badlands_palette_slot))
	context.update(var_to_bytes(b.build_swamp_water(arrays,resolution)))
	return context.finish().hex_encode()
func _initialize()->void:
	var records:Array=[];var mixed_slots:bool=false
	for seed_id:int in [73921,17,92881]:
		for mode:String in ["badlands","mixed","quarry_control"]:
			var p:Vector2=locate(builder_for(seed_id,mode,256),mode)
			for dimensions:Vector2i in [Vector2i(256,64),Vector2i(4096,32),Vector2i(16384,32)]:
				var hashes:Array[String]=[]
				var coordinate:=Vector2i(floori(p.x/dimensions.x),floori(p.y/dimensions.x))
				for enabled:bool in [false,true]:
					var b=builder_for(seed_id,mode,dimensions.x);b.interleave_badlands_normals=enabled
					var arrays:Array=b.build(coordinate,dimensions.y)
					hashes.append(digest(b,arrays,dimensions.y))
					mixed_slots=mixed_slots or b.built_badlands_palette_slot==8
				assert(hashes[0]==hashes[1],"Interleaving changed terrain, water or metadata")
				records.append({"seed":seed_id,"mode":mode,"span_m":dimensions.x,"resolution":dimensions.y,"cell":coordinate,"sha256":hashes[0]})
	assert(mixed_slots,"Real nine-slot Badlands/Quarry tiles exercised")
	var result:Dictionary={"checks":records.size()+1,"failures":[],"passed":true,"records":records,"nine_slot_tiles_exercised":mixed_slots,"builder_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd"),"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Exact complete terrain arrays, atlas, slot/mask and water arrays; three seeds, near/sparse meshes and actual mixed owners. Not a runtime benchmark."}
	FileAccess.open("res://tools/badlands/artifacts/check_normal_interleave.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BADLANDS_NORMAL_INTERLEAVE ",result.checks," checks");quit()
