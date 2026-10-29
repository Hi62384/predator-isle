extends "res://tools/preview_erosion.gd"

func run() -> void:
	var builder=load("res://scripts/terrain_mesh_builder.gd").new()
	builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.grass_coverage=100
	builder.settings.desert_coverage=0
	builder.settings.snow_coverage=0
	builder.settings.stone_coverage=0
	builder._configure_noise()
	var candidates: Array=[]
	for z in range(-120,121):
		for x in range(-120,121):
			var p:=Vector3(x*160.0,0,z*160.0)
			p.y=builder._get_height(p.x,p.z)
			if p.y<80 or builder._last_geology.z<0.2: continue
			for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
				var foot: float=builder._get_height(p.x+direction.x*180,p.z+direction.z*180)
				if foot>10 and foot<p.y-45:
					candidates.append([p.y-foot,p,direction*380+Vector3(30,100,30)])
	candidates.sort_custom(func(a,b): return a[0]>b[0])
	var sites: Array=[]
	for candidate in candidates:
		var separated:=true
		for site in sites:
			if candidate[1].distance_to(site[1])<1200: separated=false
		if separated: sites.append(candidate)
		if sites.size()==5: break
	if sites.size()<5:
		push_error("Need five separated cliff sites; found %d" % sites.size())
		quit(1)
		return
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	for i in range(sites.size()):
		await capture(scene,"ambient_site_%d" % i,sites[i][1],sites[i][2])
	scene.queue_free()
	await process_frame
	quit()
