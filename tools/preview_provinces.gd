extends "res://tools/preview_erosion.gd"

func run() -> void:
	var builder=load("res://scripts/terrain_mesh_builder.gd").new()
	builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.grass_coverage=100
	builder.settings.desert_coverage=0;builder.settings.snow_coverage=0;builder.settings.stone_coverage=0
	builder._configure_noise()
	var sites: Dictionary={};var scores: Dictionary={}
	for z in range(-60,61):
		for x in range(-60,61):
			var px:=x*700.0;var pz:=z*700.0
			var height: float=builder._get_height(px,pz)
			if height<8 or builder._last_island<0.02: continue
			var surface: Vector2=builder._last_surface
			var geo: Vector3=builder._last_geology
			var province: Vector2=builder.geographic_identity(px,pz)
			var candidates: Dictionary={"province_plain":(1-province.x)*100.0-height,"province_ridge":height+surface.x*120.0-geo.z*300.0,"province_basin":surface.y*100.0-height}
			for label in candidates:
				var score: float=candidates[label]
				if score>scores.get(label,-INF): scores[label]=score;sites[label]=Vector3(px,height,pz)
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene);scene.get_node("FreeCamera").set_process(false);scene.get_node("Interface").hide()
	for label in sites:
		await capture(scene,label,sites[label],Vector3(1100,600,1200))
	scene.queue_free();await process_frame;quit()
