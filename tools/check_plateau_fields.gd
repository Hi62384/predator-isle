extends SceneTree

func final_height(p: Vector3) -> float:
	return lerpf(maxf(1.0,p.x),p.z,p.y)

func _initialize() -> void:
	var b=load("res://scripts/terrain_mesh_builder.gd").new()
	b.settings=load("res://terrain_settings.tres").duplicate(true)
	b._configure_noise()
	var errors: Array[float]=[]
	var max_error:=0.0
	var squared:=0.0
	var worst:=Vector2.ZERO
	for i in range(5000):
		var x:=sin(i*1.713)*4000.0
		var z:=cos(i*2.121)*4000.0
		var cached: Vector3=b._grass_sample(x,z)
		var exact: Vector3=b._grass_sample_raw(x,z)
		var error:=absf(final_height(cached)-final_height(exact))
		errors.append(error)
		squared+=error*error
		if error>max_error: max_error=error;worst=Vector2(x,z)
	errors.sort()
	print("STRUCTURAL_GRID height error m rms=",sqrt(squared/errors.size())," p95=",errors[int(errors.size()*0.95)]," max=",max_error," at=",worst)
	assert(max_error<4.0,"Structural lattice exceeds documented error budget")
	assert(b._grass_grid.size()<=8192)
	# Conservative coast certificates must not alter heights at any island size.
	for size in [128.0,1388.89,100400.0]:
		b.settings.island_size=size
		b._configure_noise()
		for i in range(500):
			var x:=i*17.17-4000.0
			var z:=i*3.37+73.0
			var warm: float=b._get_height(x,z)
			b._coast_certificates.clear()
			var cold: float=b._get_height(x,z)
			assert(is_equal_approx(warm,cold),"Coast certificate changed height")
	print("PASS bounded structural cache and coast certificates at three island scales")
	quit()
