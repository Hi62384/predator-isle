extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	assert(ok,label)
func builder(seed_value:int=73921):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.mountain_coverage=0;b.world_seed=seed_value
	b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.savanna_coverage=0;b.settings.jungle_coverage=0;b.settings.swamp_coverage=100;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var samples:Array=[]
		for i in range(160):
			var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
			var h:float=b._sample_grid_height(p.x,p.y);samples.append([p,h,b._last_swamp.duplicate(),b._last_swamp_water])
			check(is_finite(h) and is_finite(b._last_swamp_water),"Finite land and local water")
			for v:float in b._last_swamp:check(v==floorf(v) and v>=0 and v<=16777215,"Exact float24")
			check(h==b._get_height(p.x,p.y,false),"Height-only queries identical")
		b._height_grid_cache.clear();b._swamp._nodes.clear();b._swamp._regions.clear();b._swamp._pools.clear()
		samples.reverse()
		for a:Array in samples:
			check(a[1]==b._sample_grid_height(a[0].x,a[0].y) and a[2]==b._last_swamp and a[3]==b._last_swamp_water,"Eviction and order independent water + land + controls")
		for x:float in [-128,0,256,1024]:
			for z:float in [-128,0,256]:
				var h:float=b._swamp.sample(x,z);var dx1:float=(h-b._swamp.sample(x-.02,z))/.02;var dx2:float=(b._swamp.sample(x+.02,z)-h)/.02
				check(absf(dx1-dx2)<.005,"C1 canonical land boundary")
		b.settings.swamp.flood_stage=1;b.settings.swamp.exposed_season=1;b.settings.water_enabled=false;b._configure_noise()
		for a:Array in samples:check(a[1]==b._sample_grid_height(a[0].x,a[0].y) and a[3]==b._last_swamp_water,"Season/stage/renderer never regenerates geography")
		check(b._swamp._nodes.size()<=16384 and b._swamp._regions.size()<=2048 and b._swamp._pools.size()<=512,"Bounded per-worker caches")
	var b=builder()
	check(b.is_pure_swamp_rect(Rect2(Vector2(-16384,-16384),Vector2(32768,32768))),"Pure Swamp distant refinement certificate")
	var a:Array=b.build(Vector2i(21,17),64);var right:Array=b.build(Vector2i(22,17),64)
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent land seam")
		check(a[Mesh.ARRAY_TEX_UV][i].x==right[Mesh.ARRAY_TEX_UV][j].x,"Adjacent local-water seam")
		check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent normals")
		for k in range(4):check(a[Mesh.ARRAY_CUSTOM3][i*4+k]==right[Mesh.ARRAY_CUSTOM3][j*4+k],"Adjacent payload")
	var parent:Array=b.build(Vector2i(21,17),16)
	for z in range(17):
		for x in range(17):
			var i:int=z*17+x;var j:int=z*4*65+x*4
			check(parent[Mesh.ARRAY_VERTEX][i].y==a[Mesh.ARRAY_VERTEX][j].y,"Shared LOD land vertex")
			check(parent[Mesh.ARRAY_TEX_UV][i].x==a[Mesh.ARRAY_TEX_UV][j].x,"Shared LOD water vertex")
	var water:Array=b.build_swamp_water(a,64)
	check(not water.is_empty(),"Numerical chunk water surface produced")
	if not water.is_empty():
		check(water[Mesh.ARRAY_VERTEX].size()==65*65,"No puddle nodes, one shared water grid")
		for i in range(0,water[Mesh.ARRAY_VERTEX].size(),97):
			check(water[Mesh.ARRAY_VERTEX][i].y==a[Mesh.ARRAY_TEX_UV][i].x and water[Mesh.ARRAY_TEX_UV][i].x==a[Mesh.ARRAY_VERTEX][i].y,"Water/land same topology and exact clipping height")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/swamp_previews.json"));var levels:Array=[];var flooded:int=0;var dry:int=0
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
		levels.append(surface);check(h> -100 and surface>=0,"Real preview levels")
		if h<surface:flooded+=1
		else:dry+=1
	check(flooded>5 and dry>1,"Both flooded and raised ground")
	levels.sort();check(levels.back()-levels.front()>2,"Independent inland water elevations, not one plane")
	var anchor:float=b._swamp.sample(1234,5678);var anchor_state:PackedFloat64Array=b._swamp.state.duplicate()
	for i in range(18000):b._swamp.sample(float(i*97),float((i*131)%700000))
	check(b._swamp._nodes.size()<=16384 and b._swamp._regions.size()<=2048 and b._swamp._pools.size()<=512,"Exploration eviction keeps caches bounded")
	check(anchor==b._swamp.sample(1234,5678) and anchor_state==b._swamp.state,"Real cache eviction preserves full water state")
	var mixed=builder();mixed.settings.grass_coverage=20;mixed.settings.forest_coverage=20;mixed.settings.savanna_coverage=20;mixed.settings.jungle_coverage=20;mixed.settings.grass_region_size=8000;mixed._configure_noise()
	for i in range(300):
		var w:Vector4=mixed._biome_weights(i*7919%100000-50000,i*11939%100000-50000)
		check(absf(w.x+w.y+w.z+w.w+mixed._jungle_weight-1)<.00001,"Five-biome mass")
	if FileAccess.file_exists("res://tools/swamp/baseline/builder.gd"):
		for kind in range(5):
			var current=builder();current.settings.swamp_coverage=0;current.settings.grass_coverage=100 if kind==0 or kind==4 else 0;current.settings.forest_coverage=100 if kind==1 or kind==4 else 0;current.settings.savanna_coverage=100 if kind==2 or kind==4 else 0;current.settings.jungle_coverage=100 if kind==3 or kind==4 else 0;current._configure_noise()
			var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/swamp/baseline/builder.gd").new();old.settings=current.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			for point:Vector2i in [Vector2i(21,17),Vector2i(-11,29)]:
				check(current.build(point,16)==old.build(point,16),"Swamp disabled preserves complete previous mesh arrays")
	FileAccess.open("res://tools/swamp/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"elapsed_s":float(Time.get_ticks_msec()-start)/1000,"passed":true,"scope":"Terrain and water; no collision system installed"},"\t"))
	print("SWAMP_INVARIANTS_PASS ",checks);quit()
