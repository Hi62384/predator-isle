extends SceneTree
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.mountain_coverage=0;b.settings.rocky_coast_enabled=false
	b.settings.forest_coverage=0;b.settings.swamp_coverage=0;b.settings.savanna_coverage=0;b.settings.grass_coverage=0;b.settings.jungle_coverage=100;b._configure_noise()
	var hook=preload("res://scripts/jungle_placement.gd")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/jungle_previews.json"));var item:Dictionary=manifest.features.lowland_rainforest
	var bounds:=Rect2(Vector2(item.x,item.z)-Vector2(384,384),Vector2(768,768));var a:Dictionary=hook.candidates(b,bounds);b._configure_noise();var c:Dictionary=hook.candidates(b,bounds)
	assert(a==c and a.candidates.size()>0 and a.candidates.size()<=128 and a.cells_probed<=512)
	var cells:Dictionary={};var count:int=0;var page:Dictionary=a
	while true:
		for candidate:Dictionary in page.candidates:
			assert(not cells.has(candidate.cell));cells[candidate.cell]=true;count+=1
			assert(bounds.has_point(Vector2(candidate.position.x,candidate.position.z)))
			assert(candidate.position.y>b.water_level+.5 and candidate.habitat.water<1 and not candidate.habitat.waterfall_candidate)
		if page.complete:break
		page=hook.candidates(b,bounds,24,128,page.next_offset)
	var water:Dictionary=manifest.features.jungle_river;var mask:Dictionary=hook.habitat(b,water.x,water.z);assert(mask.canopy==0)
	b.settings.jungle.canopy_density=0;b._configure_noise();assert(hook.candidates(b,bounds).candidates.is_empty())
	print("JUNGLE_PLACEMENT_PASS ",count," deterministic candidates; paged/bounded; zero submerged placement; density zero respected; no nodes spawned");quit()
