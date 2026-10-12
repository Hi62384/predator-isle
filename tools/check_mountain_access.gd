extends SceneTree

func _initialize() -> void:
	var sampler = load("res://scripts/terrain_mesh_builder.gd").new()
	sampler.settings = load("res://terrain_settings.tres").duplicate(true)
	sampler.settings.desert_coverage = 0
	sampler.settings.snow_coverage = 0
	sampler.settings.stone_coverage = 0
	sampler._configure_noise()
	const SIDE := 97
	const STEP := 64.0
	var heights := PackedFloat32Array()
	heights.resize(SIDE*SIDE)
	var peak := 0
	for z in range(SIDE):
		for x in range(SIDE):
			var i := z*SIDE+x
			heights[i] = sampler._get_height((x-48)*STEP,(z-48)*STEP)
			if heights[i]>heights[peak]:
				peak = i
	assert(heights[peak]>200.0)
	var queue: Array[int] = [peak]
	var visited := PackedByteArray()
	visited.resize(SIDE*SIDE)
	visited[peak] = 1
	var head := 0
	var reached := false
	while head<queue.size():
		var i := queue[head]
		head += 1
		if heights[i]<heights[peak]*0.35 and heights[i]>2.0:
			reached = true
			break
		for dz in range(-1,2):
			for dx in range(-1,2):
				if dx == 0 and dz == 0:
					continue
				var nx := i%SIDE+dx
				var nz := i/SIDE+dz
				if nx<0 or nz<0 or nx>=SIDE or nz>=SIDE:
					continue
				var j := nz*SIDE+nx
				if visited[j] != 0 or heights[j]<2.0:
					continue
				if absf(heights[i]-heights[j])/(STEP*sqrt(float(dx*dx+dz*dz)))>tan(deg_to_rad(35.0)):
					continue
				var last := heights[i]
				var passable := true
				for sub in range(1,9):
					var px := (float(i%SIDE-48)+dx*sub/8.0)*STEP
					var pz := (float(i/SIDE-48)+dz*sub/8.0)*STEP
					var h: float = sampler._get_height(px,pz)
					if h<2.0 or absf(h-last)/(STEP*sqrt(float(dx*dx+dz*dz))/8.0)>tan(deg_to_rad(35.0)):
						passable = false
						break
					last = h
				if not passable:
					continue
				visited[j] = 1
				queue.append(j)
	if not reached:
		var accessible_min := INF
		for i in queue:
			accessible_min = minf(accessible_min,heights[i])
		push_error("No route: peak=%s reachable_min=%s nodes=%s" % [heights[peak],accessible_min,head])
		print("Peak index ",peak," neighbors ",heights.slice(maxi(0,peak-3),mini(heights.size(),peak+4)))
		for offset in range(-2,3):
			var px := (peak%SIDE-48+offset)*STEP
			var pz := (peak/SIDE-48)*STEP
			print(px," ",pz," profile ",sampler._grass_sample(px,pz)," region ",sampler._grass_region.get_noise_2d(px,pz))
		quit(1)
		return
	print("PASS sampled 35-degree route from summit ",heights[peak]," m to lowlands; checked ",head," nodes (not a physics-controller test)")
	quit()
