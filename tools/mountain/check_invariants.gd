extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	assert(ok,label)
func builder(seed_value:int=73921):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.world_seed=seed_value
	b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.savanna_coverage=0;b.settings.jungle_coverage=0;b.settings.swamp_coverage=0;b.settings.mountain_coverage=100;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var samples:Array=[]
		for i in range(160):
			var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
			var h:float=b._sample_grid_height(p.x,p.y);samples.append([p,h,b._last_mountain.duplicate(),b._last_swamp_water])
			check(is_finite(h) and is_finite(b._last_swamp_water),"Finite land and local water")
			for v:float in b._last_mountain.slice(0,3):check(v==floorf(v) and v>=0 and v<=16777215,"Exact float24")
			check(h==b._get_height(p.x,p.y,false),"Height-only queries identical")
		b._height_grid_cache.clear();b._mountain._nodes.clear();b._mountain._regions.clear();b._mountain._landmarks.clear()
		samples.reverse()
		for a:Array in samples:
			check(a[1]==b._sample_grid_height(a[0].x,a[0].y) and a[2]==b._last_mountain and a[3]==b._last_swamp_water,"Eviction and order independent water + land + controls")
		for x:float in [-128,0,256,1024]:
			for z:float in [-128,0,256]:
				var h:float=b._mountain.sample(x,z);var dx1:float=(h-b._mountain.sample(x-.02,z))/.02;var dx2:float=(b._mountain.sample(x+.02,z)-h)/.02
				check(absf(dx1-dx2)<.005,"C1 canonical land boundary")
		b.settings.mountain.normal_strength=0;b.settings.water_enabled=false;b._configure_noise()
		for a:Array in samples:check(a[1]==b._sample_grid_height(a[0].x,a[0].y) and a[3]==b._last_swamp_water,"Material and renderer never regenerate geography")
		check(b._mountain._nodes.size()<=16384 and b._mountain._regions.size()<=2048 and b._mountain._landmarks.size()<=1024,"Bounded per-worker caches")
	var b=builder()
	check(b.is_pure_mountain_rect(Rect2(Vector2(-16384,-16384),Vector2(32768,32768))),"Pure Swamp distant refinement certificate")
	var a:Array=b.build(Vector2i(21,17),64);var right:Array=b.build(Vector2i(22,17),64)
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent land seam")
		check(a[Mesh.ARRAY_TEX_UV][i].x==right[Mesh.ARRAY_TEX_UV][j].x,"Adjacent local-water seam")
		check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent normals")
		var stride:int=a[Mesh.ARRAY_CUSTOM0].size()/a[Mesh.ARRAY_VERTEX].size()
		for k in range(stride):check(a[Mesh.ARRAY_CUSTOM0][i*stride+k]==right[Mesh.ARRAY_CUSTOM0][j*stride+k],"Adjacent payload")
	var parent:Array=b.build(Vector2i(21,17),16)
	for z in range(17):
		for x in range(17):
			var i:int=z*17+x;var j:int=z*4*65+x*4
			check(parent[Mesh.ARRAY_VERTEX][i].y==a[Mesh.ARRAY_VERTEX][j].y,"Shared LOD land vertex")
			check(parent[Mesh.ARRAY_TEX_UV][i].x==a[Mesh.ARRAY_TEX_UV][j].x,"Shared LOD water vertex")
	var lake=JSON.parse_string(FileAccess.get_file_as_string("res://data/mountain_previews.json")).features.valley_lake
	var wet_arrays:Array=b.build(Vector2i(floori(lake.x/256),floori(lake.z/256)),64)
	var water:Array=b.build_swamp_water(wet_arrays,64)
	check(not water.is_empty(),"Numerical chunk water surface produced")
	if not water.is_empty():
		check(water[Mesh.ARRAY_VERTEX].size()==65*65,"No puddle nodes, one shared water grid")
		for i in range(0,water[Mesh.ARRAY_VERTEX].size(),97):
			check(water[Mesh.ARRAY_VERTEX][i].y==wet_arrays[Mesh.ARRAY_TEX_UV][i].x and water[Mesh.ARRAY_TEX_UV][i].x==wet_arrays[Mesh.ARRAY_VERTEX][i].y,"Water/land same topology and exact clipping height")
			check(water[Mesh.ARRAY_COLOR][i].b==0 and water[Mesh.ARRAY_TEX_UV2][i].y<0,"Mountain water cannot receive Swamp flood stage")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/mountain_previews.json"));var levels:Array=[];var flooded:int=0;var dry:int=0
	for lod in range(1,7):
		b.chunk_size=256*float(1<<lod);var large:Array=b.build(Vector2i.ONE,16)
		b.chunk_size=256*float(1<<(lod-1));var small:Array=b.build(Vector2i(2,2),16)
		for z in range(9):
			for x in range(9):
				var i:int=z*17+x;var j:int=z*2*17+x*2
				check(large[Mesh.ARRAY_VERTEX][i].y==small[Mesh.ARRAY_VERTEX][j].y,"Parent/child world height LOD "+str(lod))
				check(large[Mesh.ARRAY_TEX_UV][i].x==small[Mesh.ARRAY_TEX_UV][j].x,"Parent/child local water LOD "+str(lod))
				check(large[Mesh.ARRAY_NORMAL][i].is_equal_approx(small[Mesh.ARRAY_NORMAL][j]),"Parent/child normal LOD "+str(lod))
	b.chunk_size=256
	for name:String in manifest.features:
		if name.ends_with("_transition"):continue
		var item:Dictionary=manifest.features[name];var h:float=b._get_height(item.x,item.z);var surface:float=b._last_swamp_water
		levels.append(surface);check(is_finite(h) and surface>=0,"Real preview levels")
		if h<surface:flooded+=1
		else:dry+=1
	check(flooded>=3 and dry>1,"Both flooded and raised ground")
	levels.sort();check(levels.back()-levels.front()>2,"Independent inland water elevations, not one plane")
	var anchor:float=b._mountain.sample(1234,5678);var anchor_state:PackedFloat64Array=b._mountain.state.duplicate()
	for i in range(4000):b._mountain.sample(float(i*97),float((i*131)%700000))
	check(b._mountain._nodes.size()<=16384 and b._mountain._regions.size()<=2048 and b._mountain._landmarks.size()<=1024,"Exploration eviction keeps caches bounded")
	check(anchor==b._mountain.sample(1234,5678) and anchor_state==b._mountain.state,"Real cache eviction preserves full water state")
	var mixed=builder();mixed.settings.mountain_coverage=20;mixed.settings.swamp_coverage=20;mixed.settings.grass_coverage=20;mixed.settings.forest_coverage=20;mixed.settings.savanna_coverage=20;mixed.settings.jungle_coverage=20;mixed.settings.grass_region_size=8000;mixed._configure_noise()
	for i in range(300):
		var w:Vector4=mixed._biome_weights(i*7919%100000-50000,i*11939%100000-50000)
		check(absf(w.x+w.y+w.z+w.w+mixed._jungle_weight+mixed._mountain_weight-1)<.00001,"Six-biome mass")
	if FileAccess.file_exists("res://tools/mountain/baseline/builder.gd"):
		for kind in range(6):
			var current=builder();current.settings.mountain_coverage=0;current.settings.swamp_coverage=100 if kind==4 or kind==5 else 0;current.settings.grass_coverage=100 if kind==0 or kind==5 else 0;current.settings.forest_coverage=100 if kind==1 or kind==5 else 0;current.settings.savanna_coverage=100 if kind==2 or kind==5 else 0;current.settings.jungle_coverage=100 if kind==3 or kind==5 else 0;current._configure_noise()
			var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/mountain/baseline/builder.gd").new();old.settings=current.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			for point:Vector2i in [Vector2i(21,17),Vector2i(-11,29)]:
				check(current.build(point,16)==old.build(point,16),"Swamp disabled preserves complete previous mesh arrays")
	FileAccess.open("res://tools/mountain/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"elapsed_s":float(Time.get_ticks_msec()-start)/1000,"passed":true,"scope":"Terrain and water; no collision system installed"},"\t"))
	print("MOUNTAIN_INVARIANTS_PASS ",checks);quit()
