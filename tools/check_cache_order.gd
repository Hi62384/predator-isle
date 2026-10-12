extends SceneTree

func _initialize() -> void:
	var script=load("res://scripts/terrain_mesh_builder.gd")
	var warm=script.new()
	warm.settings=TerrainSettings.new()
	warm._configure_noise()
	var cold=script.new()
	cold.settings=warm.settings.duplicate(true)
	cold._configure_noise()
	var points: Array[Vector2]=[]
	var values: Array[Vector3]=[]
	for i in range(3000):
		var p=Vector2(sin(i*1.718)*40000.0,cos(i*2.123)*40000.0)
		points.append(p)
		values.append(Vector3(warm._get_height(p.x,p.y),warm._last_surface.x,warm._last_surface.y))
	for i in range(points.size()-1,-1,-1):
		var p=points[i]
		var actual=Vector3(cold._get_height(p.x,p.y),cold._last_surface.x,cold._last_surface.y)
		assert(actual.is_equal_approx(values[i]),"Cache ordering changed canonical terrain at "+str(p))
	assert(warm._island_cache.size()<=513 and warm._plane_cache.size()<=128)
	assert(warm._river_cache.size()<=4096 and warm._river_columns.size()<=2048)
	assert(warm._lake_cache.size()<=256 and warm._label_cache.size()<=4096)
	assert(warm._grass_grid.size()<=8192 and warm._coast_certificates.size()<=512)
	assert(warm._biome_cell_cache.size()<=4096)
	for i in range(1200):
		var p:=Vector2(roundf(sin(i*1.31)*4000),roundf(cos(i*1.17)*4000))
		var value: float=warm._sample_grid_height(p.x,p.y)
		var geo: Vector3=warm._last_geology
		var surface: Vector2=warm._last_surface
		assert(is_equal_approx(value,cold._get_height(p.x,p.y)))
		assert(geo.is_equal_approx(cold._last_geology) and surface.is_equal_approx(cold._last_surface))
		assert(is_equal_approx(value,warm._sample_grid_height(p.x,p.y)))
		assert(geo.is_equal_approx(warm._last_geology))
		assert(is_equal_approx(warm._sample_grid_height(p.x+0.125,p.y+0.375),cold._get_height(p.x+0.125,p.y+0.375)))
	assert(warm._height_grid_cache.size()<=8192)
	# The quartet cache must preserve the original continuous biome weights.
	var step: float=maxf(warm._minimum_region_size/(maxf(warm.settings.height_blend,0.1)*4.0),1.0)
	for p in points:
		var cell:=Vector2i(floori(p.x/step),floori(p.y/step))
		var fx:=smoothstep(0,1,p.x/step-cell.x)
		var fz:=smoothstep(0,1,p.y/step-cell.y)
		var expected:=Vector4.ZERO
		expected[warm._grid_owner(cell.x,cell.y,step)]+=(1-fx)*(1-fz)
		expected[warm._grid_owner(cell.x+1,cell.y,step)]+=fx*(1-fz)
		expected[warm._grid_owner(cell.x,cell.y+1,step)]+=(1-fx)*fz
		expected[warm._grid_owner(cell.x+1,cell.y+1,step)]+=fx*fz
		assert(expected.is_equal_approx(warm._biome_weights(p.x,p.y)))
	print("PASS 3000 reverse-order heights/control fields and bounded cache sizes")
	quit()
