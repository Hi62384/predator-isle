extends "res://tools/desert/preview_desert.gd"
## Natural geography only: discover all five families in three signed seeds,
## then render through the real controller. No forced family/height overrides.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const FAMILIES=["transverse","longitudinal","barchan","star","parabolic"]
var failures:Array[String]=[]
var landmarks:Array=[]
func run()->void:
	started=Time.get_ticks_msec()
	if DisplayServer.get_name()=="headless":push_error("Rendered viewport required");quit(2);return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path in ["scripts/desert_sampler.gd","scripts/desert_drainage.gd","scripts/desert_settings.gd","scripts/terrain_mesh_builder.gd","scripts/chunk_terrain.gd","shaders/terrain_biomes.gdshader","shaders/desert_control_decode.gdshaderinc","shaders/desert_material.gdshaderinc","config/biomes/desert_settings.tres","config/world/terrain_settings.tres","scenes/main.tscn","tools/desert/preview_desert.gd","tools/desert/review_dune_matrix.gd"]:
		run_source_hashes[path]=FileAccess.get_sha256("res://"+path)
	for seed_value in [73921,-91827,214748]:
		var builder=Builder.new()
		builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		builder.settings.grass_coverage=0;builder.settings.desert_coverage=100
		builder.settings.snow_coverage=0;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false
		builder.world_seed=seed_value;builder._configure_noise()
		var best:Array=[]
		for family in range(5):best.append({"score":0.0})
		for z in range(-128,129):
			for x in range(-128,129):
				var p:=Vector2(x*512,z*512)
				var h:float=builder._get_height(p.x,p.y)
				var s=builder._desert
				# Require roughly five kilometres of inland clearance, so aerial
				# reviews inspect a dune field rather than mostly offshore water.
				if s.last_weights.size()<7 or s.last_weights[0]<0.65 or s.control_region.w<0.3:continue
				# _last_island may be a saturated inland certificate from a height
				# query, not a coast distance. The public mask remains exact.
				if builder._island_mask(p.x,p.y)<0.10:continue
				var family:int=s.last_family
				var score:float=s.last_weights[0]*s.control_region.w
				if family>=2:
					var width:float=s._dune_width*(1.45 if family==3 else (0.8 if family==4 else 1.0))
					score*=s._isolated_dunes(s.wind_coordinates(p.x,p.y),width,family)/maxf(s.settings.dune_max_height,1.0)
				else:score*=0.2+s.last_crest*0.8
				if score>best[family].score:best[family]={"score":score,"point":p,"height":h}
			if z%32==0:await process_frame
		scene=load("res://scenes/main.tscn").instantiate()
		terrain=scene.get_node("Terrain");terrain.settings=builder.settings;terrain.world_seed=seed_value
		camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		root.add_child(scene);scene.get_node("Interface").hide()
		for family in range(5):
			var item:Dictionary=best[family]
			if item.score<=0.01:failures.append("No natural %s landmark in seed %s"%[FAMILIES[family],seed_value]);continue
			var p:Vector2=item.point
			var focus:=Vector3(p.x,item.height,p.y)
			var label:String="matrix_%s_%s"%[seed_value,FAMILIES[family]]
			landmarks.append({"seed":seed_value,"family":FAMILIES[family],"score":item.score,"x":p.x,"z":p.y,"height":item.height})
			for distance in {"ground":Vector3(-18,3,-30),"medium":Vector3(720,330,800),"aerial":Vector3(3000,1800,3200)}:
				var offset:Vector3={"ground":Vector3(-18,3,-30),"medium":Vector3(720,330,800),"aerial":Vector3(3000,1800,3200)}[distance]
				if not await capture(label+"_"+distance,focus,offset):failures.append("Capture failed "+label)
		scene.queue_free();for frame in range(4):await process_frame
		scene=null
	var report:Dictionary={"completed":failures.is_empty(),"failures":failures,"source_hashes":run_source_hashes,"landmarks":landmarks,"captures":records,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"note":"Natural discovered landmarks; actual main scene/controller. Finite three-seed coverage, not a proof for every seed. Requires visual review."}
	FileAccess.open("res://tools/desert/artifacts/dune_matrix.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("Dune matrix finished: ",records.size()," captures, failures ",failures)
	quit(0 if failures.is_empty() else 1)
