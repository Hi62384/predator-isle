extends SceneTree
func _initialize()->void:
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:builder.settings.set(key+"_coverage",0)
	builder.settings.badlands_coverage=100;builder._configure_noise()
	var terrain=load("res://scripts/chunk_terrain.gd").new();terrain._sampler=builder;terrain._settings_snapshot=builder.settings
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"));var point:=Vector2(manifest.features.eroded_ridges.x,manifest.features.eroded_ridges.z)
	var cell:=Vector2i(floori(point.x/2048),floori(point.y/2048));var chosen:=Vector3i.ZERO;var detailed:int=0
	for z in range(-2,3):
		for x in range(-2,3):
			var key:=Vector3i(cell.x+x,cell.y+z,3);var resolution:int=terrain._tile_resolution(key)
			if resolution>16:chosen=key;detailed=resolution;break
		if detailed>16:break
	assert(detailed==32,"Dissected inland LOD3 requests local 64m spacing")
	var height:float=builder._get_height(point.x,point.y)
	builder.settings.badlands.dissected_mesh_metres=256;terrain._badlands_mesh_tiles.clear()
	assert(terrain._tile_resolution(chosen)==16,"Disabling local refinement restores baseline density")
	assert(builder._get_height(point.x,point.y)==height,"Detail selection never changes canonical terrain height")
	var cap:Dictionary=manifest.features.hoodoo_cluster;var cap_cell:=Vector3i(floori(cap.x/1024),floori(cap.z/1024),2)
	terrain._badlands_mesh_tiles.clear();var cap_resolution:int=terrain._tile_resolution(cap_cell)
	assert(cap_resolution==64,"Compact caprock requests local sixteen-metre LOD2 sampling")
	var near_cap:=Vector3i(floori(cap.x/512),floori(cap.z/512),1);terrain._badlands_mesh_tiles.clear()
	assert(terrain._tile_resolution(near_cap)==64,"Compact caprock retains local eight-metre LOD1 sampling")
	builder.settings.badlands.remnants=0;terrain._badlands_mesh_tiles.clear()
	assert(terrain._tile_resolution(cap_cell)==16,"Disabling remnants removes their local refinement")
	assert(terrain._tile_resolution(near_cap)==32,"Disabling remnants restores the ordinary LOD1 mesh")
	builder.settings.badlands_coverage=0;builder.settings.grass_coverage=100;builder._configure_noise();terrain._badlands_mesh_tiles.clear()
	assert(terrain._tile_resolution(chosen)==16 and terrain._badlands_mesh_tiles.is_empty(),"Disabled Badlands leaves other terrain density unchanged")
	assert(terrain.maximum_lod==6,"Large hierarchy unchanged")
	var report:Dictionary={"checks":9,"failures":[],"cell":chosen,"refined_resolution":detailed,"baseline_resolution":16,"caprock_lod2_resolution":cap_resolution,"caprock_lod1_resolution":64,"chunk_terrain_sha256":FileAccess.get_sha256("res://scripts/chunk_terrain.gd"),"scope":"Local selected-region refinement only; canonical world height, hierarchy and other-biome density preserved; compact remnant refinement switches off with its generator"}
	FileAccess.open("res://tools/badlands/artifacts/check_detail_selection.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_DETAIL_SELECTION ",report);terrain.free();quit()
