extends SceneTree

var worker_result: Array

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var sampler = script.new()
	sampler.settings = TerrainSettings.new()
	sampler.settings.grass_coverage = 100
	for key:String in ["forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:sampler.settings.set(key+"_coverage",0)
	sampler.settings.island_size = 12000
	sampler._configure_noise()
	var copy = script.new()
	copy.settings = sampler.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	copy._configure_noise()
	var minimum := INF
	var maximum := -INF
	var plains := 0
	var wet := 0
	var mountains := 0
	for z in range(-70,70):
		for x in range(-70,70):
			var p := Vector2(x*250.0,z*250.0)
			var value: Vector3 = sampler._grass_sample(p.x,p.y)
			assert(value.is_equal_approx(copy._grass_sample(p.x,p.y)))
			minimum = minf(minimum,value.x)
			maximum = maxf(maximum,value.x)
			if value.y > 0.95:
				wet += 1
			if value.x > 200:
				mountains += 1
			var dx: Vector3 = sampler._grass_sample(p.x+100,p.y)
			var dz: Vector3 = sampler._grass_sample(p.x,p.y+100)
			if value.y < 0.01 and absf(dx.x-value.x)<0.5 and absf(dz.x-value.x)<0.5:
				plains += 1
	assert(plains>50 and mountains>50 and wet>10 and maximum-minimum>250)
	var fine: Array = sampler.build(Vector2i(-1,0),64)
	var coarse: Array = copy.build(Vector2i(-1,0),16)
	var neighbor: Array = copy.build(Vector2i(0,0),64)
	var fv: PackedVector3Array = fine[Mesh.ARRAY_VERTEX]
	var cv: PackedVector3Array = coarse[Mesh.ARRAY_VERTEX]
	var nv: PackedVector3Array = neighbor[Mesh.ARRAY_VERTEX]
	var fn: PackedVector3Array = fine[Mesh.ARRAY_NORMAL]
	var cn: PackedVector3Array = coarse[Mesh.ARRAY_NORMAL]
	var nn: PackedVector3Array = neighbor[Mesh.ARRAY_NORMAL]
	var fu: PackedVector2Array = fine[Mesh.ARRAY_TEX_UV]
	var cu: PackedVector2Array = coarse[Mesh.ARRAY_TEX_UV]
	var nu: PackedVector2Array = neighbor[Mesh.ARRAY_TEX_UV]
	var fs: PackedVector2Array = fine[Mesh.ARRAY_TEX_UV2]
	var cs: PackedVector2Array = coarse[Mesh.ARRAY_TEX_UV2]
	var ns: PackedVector2Array = neighbor[Mesh.ARRAY_TEX_UV2]
	var fg: PackedFloat32Array = fine[Mesh.ARRAY_CUSTOM0]
	var cg: PackedFloat32Array = coarse[Mesh.ARRAY_CUSTOM0]
	var ng: PackedFloat32Array = neighbor[Mesh.ARRAY_CUSTOM0]
	assert(fg.size()==fv.size()*3)
	for z in range(65):
		assert(is_equal_approx(fv[z*65+64].y,nv[z*65].y))
		assert(fn[z*65+64].is_equal_approx(nn[z*65]))
		assert(fu[z*65+64].is_equal_approx(nu[z*65]))
		assert(fs[z*65+64].is_equal_approx(ns[z*65]))
		for channel in range(3): assert(is_equal_approx(fg[(z*65+64)*3+channel],ng[z*65*3+channel]))
	for z in range(17):
		for x in range(17):
			assert(is_equal_approx(cv[z*17+x].y,fv[z*4*65+x*4].y))
			assert(cu[z*17+x].is_equal_approx(fu[z*4*65+x*4]))
			assert(cs[z*17+x].is_equal_approx(fs[z*4*65+x*4]))
			for channel in range(3): assert(is_equal_approx(cg[(z*17+x)*3+channel],fg[(z*4*65+x*4)*3+channel]))
			if x == 0 or x == 16 or z == 0 or z == 16:
				assert(cn[z*17+x].is_equal_approx(fn[z*4*65+x*4]))
	var job := WorkerThreadPool.add_task(func(): worker_result = copy.build(Vector2i(-1,0),16))
	WorkerThreadPool.wait_for_task_completion(job)
	assert(worker_result[Mesh.ARRAY_VERTEX] == coarse[Mesh.ARRAY_VERTEX])
	assert(worker_result[Mesh.ARRAY_TEX_UV2] == coarse[Mesh.ARRAY_TEX_UV2])
	assert(worker_result[Mesh.ARRAY_CUSTOM0] == coarse[Mesh.ARRAY_CUSTOM0])
	# False-color height map of the Grass landform field, independent of island clipping.
	var map := Image.create(512,512,false,Image.FORMAT_RGB8)
	for z in range(512):
		for x in range(512):
			var v: Vector3 = sampler._grass_sample((x-256)*60.0,(z-256)*60.0)
			var color := Color(0.15,0.3+clampf(v.x/650,0,1)*0.6,0.12)
			if v.y > 0.95:
				color = Color(0.06,0.4,0.8)
			map.set_pixel(x,z,color)
	map.save_png("res://tools/grass_landforms.png")
	print("PASS Grass deterministic/thread/edge/LOD tests; elevation=",minimum,"..",maximum," flat samples=",plains," mountain samples=",mountains," water samples=",wet)
	quit()
