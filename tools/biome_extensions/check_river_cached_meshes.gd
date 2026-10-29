extends SceneTree
var failures:Array=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
static func make(seed_id:int,profile:int,oracle:bool):
	var b=preload("res://tools/biome_extensions/uncached_river_builder_oracle.gd").new() if oracle else preload("res://scripts/terrain_mesh_builder.gd").new()
	b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["grass","jungle","forest","savanna","swamp","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",0)
	var sets:Array=[["grass"],["mountain"],["tropical"],["badlands"],["grass","forest","mountain","tropical","badlands"],["grass","mountain","tropical","badlands","radiation_wasteland","alien_infected"]]
	for owner:String in sets[profile]:b.settings.set(owner+"_coverage",100.0/sets[profile].size())
	b.settings.mountain.ridge_scale=1.35;b.settings.grass_river_frequency=.05 if profile>=4 else 1
	b.settings.beaches_enabled=profile>=4;b.settings.rocky_coast_enabled=profile>=4;b.settings.biome_size=.2;b.settings.island_size=100400;b.settings.island_spacing=585;b._configure_noise();return b
func payload(b,cell:Vector2i)->Array:
	var arrays:Array=b.build(cell,16)
	return [arrays,b.build_swamp_water(arrays,16),b.built_extension_data.duplicate(),b.built_badlands_palette.duplicate(),b.built_extension_mask,b.built_badlands_palette_slot]
func run()->void:
	var sources:Dictionary={}
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");sources[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/biome_extensions/check_river_cached_meshes.gd","res://tools/biome_extensions/uncached_river_builder_oracle.gd","res://tools/biome_extensions/uncached_river_mountain_oracle.gd"]:sources[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var locator=make(seed_id,0,false);var cells:Array[Vector2i]=[]
		for i in range(1200):
			var point:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
			if locator._island_mask(point.x,point.y)<.2:continue
			cells.append(Vector2i(floori(point.x/256),floori(point.y/256)))
			if cells.size()==2:break
		verify(cells.size()==2,"Two actual inland cells per seed")
		for profile in range(6):
			var cached=make(seed_id,profile,false);var oracle=make(seed_id,profile,true)
			# Deliberately contaminate the normal cache namespace before a build.
			for i in range(17):cached._grass_river_center(i*256,-3,40000 if i%2==0 else 80000);cached._river_column(i*256,-3,80000 if i%2==0 else 40000)
			var originals:Array=[]
			for cell:Vector2i in cells:originals.append(payload(cached,cell))
			for index in range(cells.size()-1,-1,-1):
				var reference:Array=payload(oracle,cells[index]);var exact:bool=originals[index]==reference
				verify(exact,"Complete cached versus uncached terrain/water/packed controls "+str([seed_id,profile,cells[index]]))
				var changed_channels:Array=[]
				if not exact:
					for channel in range(Mesh.ARRAY_MAX):
						if originals[index][0][channel]!=reference[0][channel]:changed_channels.append(channel)
				cases.append({"seed":seed_id,"profile":profile,"cell":str(cells[index]),"complete_exact":exact,"different_mesh_channels":changed_channels,"vertices":originals[index][0][Mesh.ARRAY_VERTEX].size(),"settings_river_frequency":cached.settings.grass_river_frequency,"mountain_ridge_scale":1.35})
	for path:String in sources:verify(FileAccess.get_sha256(path)==sources[path],"Stable cached-mesh source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_river_cached_meshes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"assertions":checks,"source_sha256":sources,"cases":cases,"scope":"Thirty-six complete actual mesh/water/extension/palette payload comparisons,three seeds/six owner profiles/two inland cells,normal versus cache-cleared oracle in reverse order. Uses the actual production river functions with no alternate formula;includes custom Mountain scale1.35,real mixed low-frequency spacing regimes and deliberate namespace warmup. No GPU,streamed movement,timing or all-world certificate."},"  "));print("RIVER_CACHED_MESHES ",checks," checks / failures=",failures);quit(0 if failures.is_empty() else 1)
func _initialize()->void:call_deferred("run")
