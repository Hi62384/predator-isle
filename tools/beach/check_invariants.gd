extends SceneTree
var checks:int=0
func check(value:bool,label:String)->void:
	checks+=1;assert(value,label)
func builder(seed_value:int=73921):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.world_seed=seed_value
	b.settings.beaches_enabled=true;b.settings.beach.coverage=1;b.settings.rocky_coast.coverage=1
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:b.settings.set(kind+"_coverage",100 if kind=="grass" else 0)
	b._configure_noise();return b
func _initialize()->void:
	var started:int=Time.get_ticks_msec();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json"))
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var records:Array=[]
		for item:Dictionary in manifest.features.values():
			for k in range(8):
				var p:=Vector2(item.x+sin(k*1.73)*300,item.z+cos(k*1.43)*300)
				var h:float=b._sample_grid_height(p.x,p.y);var water:float=b._last_swamp_water;var control:Vector4=b._last_coast
				check(is_finite(h) and is_finite(water) and control.is_finite(),"Finite sand geometry/payload")
				check(h==b._get_height(p.x,p.y,false),"Height-only equality")
				records.append([p,h,water,control])
		b._height_grid_cache.clear();b._coast._nodes.clear();b._coast._patches.clear();records.reverse()
		for r:Array in records:check(r[1]==b._sample_grid_height(r[0].x,r[0].y) and r[2]==b._last_swamp_water and r[3]==b._last_coast,"Sand independent of generation order/cache")
		for r:Array in records.slice(0,32):
			var x:float=roundf(r[0].x/8)*8;var z:float=roundf(r[0].y/8)*8;var h:float=b._coast.sample(x,z,0,0)
			var dl:float=(h-b._coast.sample(x-.01,z,0,0))/.01;var dr:float=(b._coast.sample(x+.01,z,0,0)-h)/.01
			check(absf(dl-dr)<.05,"C1 sand lattice boundary")
	var b=builder();var item:Dictionary=manifest.features.high_foredunes;var cell:=Vector2i(floori(item.x/256),floori(item.z/256))
	var unpruned=builder();unpruned._coast=preload("res://tools/beach/unpruned_coast.gd").new();unpruned._coast.configure(unpruned.settings.rocky_coast,unpruned.world_seed,unpruned)
	for i in range(500):
		var location:Dictionary=manifest.features.values()[i%manifest.features.size()];var x:float=roundf((location.x+sin(i*1.37)*6000)/8)*8;var z:float=roundf((location.z+cos(i*1.79)*6000)/8)*8
		var h:float=b._get_height(x,z);var water:float=b._last_swamp_water
		check(h==unpruned._get_height(x,z) and water==unpruned._last_swamp_water,"Coastal early-outs preserve complete mixed height/water")
	for name:String in ["wide_beach","high_foredunes","lagoon","tidal_flat","sandbars"]:
		var location:Dictionary=manifest.features[name];var h:float=b._get_height(location.x,location.z)
		check(b._coast.state[19]>.9,"Actual sandy feature "+name)
		if name=="high_foredunes":check(h>20,"Foredune exists above mean sea level")
		if name=="lagoon":check(h<0,"Actual flooded lagoon basin")
	var a:Array=b.build(cell,64);var right:Array=b.build(cell+Vector2i.RIGHT,64)
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent sand height")
		check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent sand normal")
		for k in range(4):check(a[Mesh.ARRAY_CUSTOM1][i*4+k]==right[Mesh.ARRAY_CUSTOM1][j*4+k],"Adjacent signed sand codec")
	for i in range(0,65*65,19):
		var packed:float=a[Mesh.ARRAY_CUSTOM1][i*4+3]
		check(packed<0,"Sand extension transported to real mesh")
		check(float((int(-packed-1)>>8)&255)/255>.99,"Sand weight decodes at full precision")
	# Exercise bounded cache eviction and compare the original canonical result.
	var shore=b._coast.beach;var point:=Vector2(item.x,item.z);var before:float=shore.shore_distance(point)
	for i in range(4200):shore._shore_node(Vector2i(i*13,i*17))
	for i in range(2200):shore.shore_distance(Vector2(i*13312,i*17408))
	check(shore._shore_nodes.size()<=4096 and shore._shore_patches.size()<=2048,"Bounded beach shoreline caches after eviction")
	check(before==shore.shore_distance(point),"Shoreline cache eviction is exact")
	for lod in range(1,7):
		b.chunk_size=256*float(1<<lod);var large:Array=b.build(Vector2i.ZERO,16)
		b.chunk_size=256*float(1<<(lod-1));var small:Array=b.build(Vector2i.ZERO,16)
		for z in range(9):
			for x in range(9):
				var i:int=z*17+x;var j:int=z*2*17+x*2
				check(large[Mesh.ARRAY_VERTEX][i].y==small[Mesh.ARRAY_VERTEX][j].y,"Parent-child same sand surface")
				check(large[Mesh.ARRAY_NORMAL][i].is_equal_approx(small[Mesh.ARRAY_NORMAL][j]),"Parent-child canonical sand normals")
	b.chunk_size=256
	for item2:Dictionary in manifest.features.values():
		var mesh:Array=b.build(Vector2i(floori(item2.x/256),floori(item2.z/256)),16);var local:Array=b.build_swamp_water(mesh,16)
		if not local.is_empty():
			for index:int in local[Mesh.ARRAY_INDEX]:check(local[Mesh.ARRAY_VERTEX][index].y>.2,"Ocean exclusively owns sea-connected lagoon water")
	# Both overlays disabled restore the archived six-biome mesh exactly.
	var reference=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/builder.gd").new()
	b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b._configure_noise()
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:b.settings.set(biome+"_coverage",100 if kind==biome else 0)
		reference.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);reference._configure_noise();b._configure_noise()
		var previous:Array=reference.build(cell,16);var current:Array=b.build(cell,16)
		for channel in range(Mesh.ARRAY_MAX):check(previous[channel]==current[channel],"Sand disabled preserves complete "+kind+" mesh channel "+str(channel))
	print("BEACH_INVARIANTS ",checks," checks, ms=",Time.get_ticks_msec()-started)
	FileAccess.open("res://tools/beach/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":true,"elapsed_ms":Time.get_ticks_msec()-started,"collision":"not installed"},"\t"));quit()
