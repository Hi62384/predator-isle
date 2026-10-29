extends SceneTree
## Same source checks can run in an isolated fixture or the real Windows project.
## These are invariants and CPU measurements, not GPU or visual acceptance.
const Builder = preload("res://scripts/terrain_mesh_builder.gd")
const Baseline = preload("res://tools/desert/baseline/builder.gd")
const Desert = preload("res://scripts/desert_sampler.gd")
var failures: Array[String] = []
var report: Dictionary = {}

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func config(grass: bool = false) -> TerrainSettings:
	var c: TerrainSettings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	c.grass_coverage = 100.0 if grass else 0.0
	c.desert_coverage = 0.0 if grass else 100.0
	c.snow_coverage = 0.0
	c.stone_coverage = 0.0
	c.temperature_enabled = false
	return c

func make_builder(script: Script, grass: bool = false):
	var b = script.new()
	b.settings = config(grass)
	b.world_seed = 73921
	b._configure_noise()
	return b

func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	var a = Desert.new()
	var b = Desert.new()
	a.configure(DesertSettings.new(), 73921)
	b.configure(DesertSettings.new(), 73921)
	var points: Array[Vector2] = []
	var heights: PackedFloat64Array = []
	var controls: Array[Vector4] = []
	for i in range(1024):
		var p := Vector2(float((i * 3793) % 211)*737.0-77553.0, float((i * 1913) % 227)*641.0-70291.0)
		points.append(p)
		heights.append(a.sample(p.x, p.y))
		controls.append(a.control_surface)
	for i in range(points.size()-1, -1, -1):
		var p: Vector2 = points[i]
		check(is_equal_approx(heights[i], b.sample(p.x,p.y)), "Query order determinism %d" % i)
		check(controls[i].is_equal_approx(b.control_surface), "Control determinism %d" % i)
		check(is_finite(heights[i]), "Finite height %d" % i)
	for i in range(3000): a.sample(i*1311.0,i*-797.0)
	check(a._region_cache.size()<=a.CACHE_LIMIT, "Bounded region cache")
	check(a._site_cache.size()<=a.CACHE_LIMIT, "Bounded descriptor cache")
	check(a._dune_cache.size()<=512, "Bounded isolated-dune cache")
	for i in range(0,1024,17):
		check(is_equal_approx(a.sample(points[i].x,points[i].y),heights[i]),"Cache eviction must not change height")
	# Width knobs and new seeds cannot inherit a stale dune descriptor cache.
	var changed: DesertSettings = DesertSettings.new()
	changed.dune_width_range = Vector2(230.0,540.0)
	a.configure(changed, 97231)
	b.configure(changed.duplicate(true),97231)
	for i in range(0,1024,11):
		check(is_equal_approx(a.sample(points[i].x,points[i].y),b.sample(points[i].x,points[i].y)),"Reconfiguration determinism")
	# No desert changes are allowed to alter pure Grass canonical heights/geology.
	var grass = make_builder(Builder, true)
	var grass_old = make_builder(Baseline, true)
	var grass_error: float = 0.0
	for i in range(0,1024,5):
		var p: Vector2 = points[i]
		grass_error=maxf(grass_error,absf(grass._get_height(p.x,p.y)-grass_old._get_height(p.x,p.y)))
		check(grass._last_geology.is_equal_approx(grass_old._last_geology),"Grass geological controls retained")
	check(grass_error<0.000001,"Grass canonical height unchanged")
	report["grass_max_height_delta_m"]=grass_error
	# Shared vertices across same and mixed LOD resolutions and chunk order.
	var terrain = make_builder(Builder)
	var left: Array = terrain.build(Vector2i.ZERO, 64)
	var right: Array = terrain.build(Vector2i(1,0), 32)
	var seam_error: float = 0.0
	for z in range(33):
		var lv: Vector3 = left[Mesh.ARRAY_VERTEX][z*2*65+64]
		var rv: Vector3 = right[Mesh.ARRAY_VERTEX][z*33]
		seam_error=maxf(seam_error,absf(lv.y-rv.y))
	check(seam_error<0.00001,"Mixed LOD shared heights")
	var parent = make_builder(Builder)
	parent.chunk_size=512.0
	var large: Array = parent.build(Vector2i.ZERO,64)
	for z in range(33):
		for x in range(33):
			check(is_equal_approx(left[Mesh.ARRAY_VERTEX][z*2*65+x*2].y,large[Mesh.ARRAY_VERTEX][z*65+x].y),"Parent-child canonical height")
	for arrays in [left,right,large]:
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		check(arrays[Mesh.ARRAY_CUSTOM1] is PackedFloat32Array and arrays[Mesh.ARRAY_CUSTOM1].size()==count*4,"Packed RGBA_FLOAT control component count")
		check(arrays[Mesh.ARRAY_CUSTOM2] is PackedFloat32Array and arrays[Mesh.ARRAY_CUSTOM2].size()==count*4,"Canonical bedding/dune controls include every vertex and skirt")
		check(arrays[Mesh.ARRAY_CUSTOM3]==null,"Unused fourth custom channel absent")
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:check(normal.is_finite() and absf(normal.length()-1.0)<0.002,"Finite unit normal")
	report["shared_seam_max_delta_m"]=seam_error
	# Extra controls allocate only on chunks with actual Desert land.
	var grass_mesh: Array=grass.build(Vector2i(-18,35),16)
	for channel in [Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
		check(grass_mesh[channel]==null,"Pure Grass has no extra Desert vertex channels")
	check(a._drainage_graph._catchments.size()<=128,"Bounded catchment descriptors")
	check(a._drainage_graph._tiles.size()<=a._drainage_graph.MAX_TILES,"Bounded drainage tile cache")
	# Shared graph endpoints and monotone edge bed metadata. Full hydrological
	# simulation and globally monotone final terrain are not implied by this check.
	var network=Desert.new();network.configure(DesertSettings.new(),73921)
	var edge_count: int=0
	var max_junction_degree: int=0
	for z in range(-2,3):
		for x in range(-2,3):
			var descriptor: Array=network._drainage_graph._catchment(Vector2i(x,z),network)
			var edges: Array=descriptor[0]
			var root: Vector2=edges[0][0]
			for node_edge: Array in edges:
				var degree: int=0
				for connected_edge: Array in edges:
					if node_edge[0].is_equal_approx(connected_edge[0]) or node_edge[0].is_equal_approx(connected_edge[1]):degree+=1
				max_junction_degree=maxi(max_junction_degree,degree)
				check(degree<=3,"Staggered tributaries have no radial multiway hub")
			for edge: Array in edges:
				edge_count+=1
				check(edge[2]<edge[3],"Nominal beds descend toward parent")
				var connected: bool=edge[0].is_equal_approx(root)
				for other: Array in edges:
					connected=connected or edge[0].is_equal_approx(other[1])
				check(connected,"Every tributary joins a shared parent endpoint")
	report["connected_graph_edges_checked"]=edge_count
	report["max_drainage_junction_degree"]=max_junction_degree
	# Tile culling cannot create height or control discontinuities. Measure the
	# maximum difference across a 2 cm seam, plus adjacent finite-difference slopes.
	var seam_height: float=0.0
	var seam_control: float=0.0
	for axis in range(2):
		for i in range(-40,41):
			for j in range(-4,5):
				var p:=Vector2(i*1024.0,j*2371.0+177.0)
				if axis==1:p=Vector2(p.y,p.x)
				var d:=Vector2(0.01,0.0) if axis==0 else Vector2(0.0,0.01)
				var h0: float=network.sample(p.x-d.x,p.y-d.y)
				var c0: Vector4=network.control_surface
				var h1: float=network.sample(p.x+d.x,p.y+d.y)
				seam_height=maxf(seam_height,absf(h1-h0))
				seam_control=maxf(seam_control,(network.control_surface-c0).length())
	check(seam_height<0.20,"Drainage tile boundary has no macroscopic height jump")
	check(seam_control<0.02,"Drainage tile boundary has no material jump")
	report["tile_boundary_2cm_max_height_delta_m"]=seam_height
	report["tile_boundary_2cm_max_control_delta"]=seam_control
	# Actual inland coordinates, chosen by fixed-seed discovery. A separate
	# underwater control makes it impossible to mistake sea-floor cost for Desert.
	var cases: Array=[
		["underwater_control",Vector2i(16,-12),256.0,64],
		["sand_sea",Vector2i(-18,35),256.0,64],
		["sand_sea_close",Vector2i(-18,35),256.0,128],
		["canyon",Vector2i(62,115),256.0,64],
		["highlands",Vector2i(-97,53),256.0,64],
		["badlands",Vector2i(9,137),256.0,64],
		["far_1024m_step",Vector2i(0,1),16384.0,16]]
	var cpu: Array=[]
	for old in [true,false]:
		for item: Array in cases:
			var times: Array[float]=[]
			var payload: int=0
			var land_vertices: int=0
			var minimum: float=INF
			var maximum: float=-INF
			for repetition in range(3):
				var builder=make_builder(Baseline if old else Builder)
				builder.chunk_size=item[2]
				var tick: int=Time.get_ticks_usec()
				var arrays: Array=builder.build(item[1],item[3])
				times.append((Time.get_ticks_usec()-tick)/1000.0)
				payload=arrays[Mesh.ARRAY_VERTEX].size()*(12+12+16+8+8+12)+arrays[Mesh.ARRAY_INDEX].size()*4
				for channel in [Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
					if arrays[channel]!=null:payload+=arrays[channel].size()*(4 if arrays[channel] is PackedFloat32Array else 1)
				land_vertices=0;minimum=INF;maximum=-INF
				for k in range((int(item[3])+1)*(int(item[3])+1)):
					var height: float=arrays[Mesh.ARRAY_VERTEX][k].y
					minimum=minf(minimum,height);maximum=maxf(maximum,height)
					if height>0.0:land_vertices+=1
			times.sort()
			if item[0]!="underwater_control":check(land_vertices>0,"CPU benchmark includes actual land: "+item[0])
			cpu.append({"case":item[0],"baseline":old,"resolution":item[3],"chunk_size_m":item[2],"coordinate":str(item[1]),"median_cold_ms":times[1],"all_ms":times,"estimated_array_payload_bytes":payload,"above_water_vertices":land_vertices,"height_min_m":minimum,"height_max_m":maximum})
	report["cpu_chunks"]=cpu
	var field_costs: Array=[]
	for old in [true,false]:
		for location in [Vector2(-4608,8960),Vector2(15872,29440),Vector2(-24832,13568)]:
			var query=make_builder(Baseline if old else Builder)
			# Same deterministic 256 m inland footprint; no mesh or LOD in query.
			for j in range(256):query._get_height(location.x+j,location.y+j)
			var tick: int=Time.get_ticks_usec()
			var checksum: float=0.0
			for j in range(10000):checksum+=query._get_height(location.x+(j*37)%256,location.y+(j*71)%256)
			field_costs.append({"baseline":old,"origin":str(location),"queries":10000,"warm_us_per_query":(Time.get_ticks_usec()-tick)/10000.0,"checksum":checksum})
	report["terrain_sampling"]=field_costs
	# The same supported oasis must disappear when there is no water plane.
	var pool=Desert.new();pool.configure(DesertSettings.new(),73921)
	var wet_height: float=pool.sample(-2304.0,3840.0,true)
	var wet_mask: float=pool.control_wind.w
	var dry_height: float=pool.sample(-2304.0,3840.0,false)
	check(pool.control_wind.w==0.0,"No oasis wetness when water is disabled")
	check(dry_height>=wet_height,"Water-disabled oasis removes depression carve")
	report["oasis_water_gate"]={"supported_height_m":wet_height,"supported_wetness":wet_mask,"disabled_height_m":dry_height}
	report["engine"]=Engine.get_version_info().string
	report["os"]=OS.get_name()
	report["native_windows"]=OS.get_name()=="Windows"
	report["baseline_note"]="Baseline source captured before changes; measured in the same process after implementation. No historical baseline time is invented."
	report["failures"]=failures
	report["duration_s"]=(Time.get_ticks_usec()-started)/1000000.0
	report["static_memory_mb"]=OS.get_static_memory_usage()/1048576.0
	var path := "res://tools/desert/cpu_checks_%s.json" % OS.get_name().to_lower()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
