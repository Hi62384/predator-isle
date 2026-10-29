extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1;assert(ok,label)
func builder(seed_value:int=73921):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.world_seed=seed_value
	b.settings.grass_coverage=100;b.settings.forest_coverage=0;b.settings.jungle_coverage=0;b.settings.savanna_coverage=0;b.settings.swamp_coverage=0;b.settings.mountain_coverage=0;b.settings.rocky_coast_enabled=true;b.settings.rocky_coast.coverage=1;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json"))
	for seed_value:int in [73921,17,92881]:
		var b=builder(seed_value);var records:Array=[]
		for i in range(120):
			var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
			for j in range(5):
				var f:Vector3=b._coast.coast_frame(p);p-=Vector2(f.y,f.z)*clampf(f.x,-40000,40000)
			p+=Vector2.from_angle(i*1.73)*350
			var h:float=b._sample_grid_height(p.x,p.y);var water:float=b._last_swamp_water;var control:Vector4=b._last_coast
			check(is_finite(h) and is_finite(water) and control.is_finite(),"Finite Coast data")
			check(h==b._get_height(p.x,p.y,false),"Height-only identity")
			records.append([p,h,water,control])
		b._height_grid_cache.clear();b._coast._nodes.clear();b._coast._patches.clear();b._coast._regions.clear();b._coast._formations.clear();records.reverse()
		for r:Array in records:check(r[1]==b._sample_grid_height(r[0].x,r[0].y) and r[2]==b._last_swamp_water and r[3]==b._last_coast,"Full Coast data independent of order/cache")
		for item:Array in records.slice(0,16):
			var x:float=roundf(item[0].x/8)*8;var z:float=roundf(item[0].y/8)*8
			var h:float=b._coast.sample(x,z,0,0);var dl:float=(h-b._coast.sample(x-.01,z,0,0))/.01;var dr:float=(b._coast.sample(x+.01,z,0,0)-h)/.01
			if absf(dl-dr)>=.04:print("COAST_C1_PROBE ",seed_value," ",Vector2(x,z)," left=",dl," right=",dr," error=",absf(dl-dr))
			check(absf(dl-dr)<.04,"C1 canonical Coast boundary")
		var p:Vector2=records[0][0];var anchor:float=b._get_height(p.x,p.y);var controls:Vector4=b._last_coast
		for i in range(8500):b._coast._node(Vector2i(i*13,i*17))
		check(b._coast._nodes.size()<=8192 and b._coast._patches.size()<=2048 and b._coast._regions.size()<=2048 and b._coast._formations.size()<=512,"Bounded Coast caches after actual eviction")
		check(anchor==b._get_height(p.x,p.y) and controls==b._last_coast,"Eviction restores exact Coast")
	var b=builder();var item:Dictionary=manifest.features.tide_pools;var cell:=Vector2i(floori(item.x/256),floori(item.z/256))
	if FileAccess.file_exists("res://tools/rocky_coast/baseline/coast_preopt.gd"):
		var reference=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/coast_preopt.gd").new();reference.configure(b.settings.rocky_coast,b.world_seed,b)
		for i in range(300):
			var x:float=item.x+sin(i*1.37)*500;var z:float=item.z+cos(i*1.79)*500
			var current:float=b._coast.sample(x,z,0,0);var expected:float=reference.sample(x,z,0,0)
			check(absf(current-expected)<.0000001 and absf(b._coast.state[1]-reference.state[1])<.0000001 and absf(b._coast.state[2]-reference.state[2])<.0000001,"Polynomial cache preserves canonical height, water and influence")
	var a:Array=b.build(cell,64);var right:Array=b.build(cell+Vector2i.RIGHT,64)
	if FileAccess.file_exists("res://tools/rocky_coast/baseline/builder_coast_preprune.gd"):
		var before=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/builder_coast_preprune.gd").new();before.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);before._configure_noise();var previous:Array=before.build(cell,64)
		var locations:Array=manifest.features.values()
		for i in range(500):
			var location:Dictionary=locations[i%locations.size()];var x:float=roundf((location.x+sin(i*1.37)*3000)/8)*8;var z:float=roundf((location.z+cos(i*1.79)*3000)/8)*8
			var current:float=b._get_height(x,z);var level:float=b._last_swamp_water;var expected:float=before._get_height(x,z)
			check(absf(current-expected)<.0000001 and absf(level-before._last_swamp_water)<.0000001,"Canonical zero-influence pruning preserves mixed boundary height and water")
		for i in range(a[Mesh.ARRAY_VERTEX].size()):
			check(a[Mesh.ARRAY_VERTEX][i].is_equal_approx(previous[Mesh.ARRAY_VERTEX][i]),"Skipping hidden inland forms preserves final Coast mesh geometry")
			check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(previous[Mesh.ARRAY_NORMAL][i]),"Skipping hidden inland forms preserves canonical normals")
			check(a[Mesh.ARRAY_TEX_UV][i].is_equal_approx(previous[Mesh.ARRAY_TEX_UV][i]),"Skipping hidden inland forms preserves water and curvature")
	for z in range(65):
		var i:int=z*65+64;var j:int=z*65
		check(a[Mesh.ARRAY_VERTEX][i].y==right[Mesh.ARRAY_VERTEX][j].y,"Adjacent Coast land")
		check(a[Mesh.ARRAY_NORMAL][i].is_equal_approx(right[Mesh.ARRAY_NORMAL][j]),"Adjacent Coast normals")
		check(a[Mesh.ARRAY_TEX_UV][i].x==right[Mesh.ARRAY_TEX_UV][j].x,"Adjacent retained water")
		for k in range(4):check(a[Mesh.ARRAY_CUSTOM1][i*4+k]==right[Mesh.ARRAY_CUSTOM1][j*4+k],"Adjacent Coast/Forest packed controls")
	for lod in range(1,7):
		b.chunk_size=256*float(1<<lod);var large:Array=b.build(Vector2i.ZERO,16)
		b.chunk_size=256*float(1<<(lod-1));var small:Array=b.build(Vector2i.ZERO,16)
		for z in range(9):
			for x in range(9):
				var i:int=z*17+x;var j:int=z*2*17+x*2
				check(large[Mesh.ARRAY_VERTEX][i].y==small[Mesh.ARRAY_VERTEX][j].y,"Parent/child Coast LOD height")
				check(large[Mesh.ARRAY_NORMAL][i].is_equal_approx(small[Mesh.ARRAY_NORMAL][j]),"Parent/child Coast LOD normals")
				check(large[Mesh.ARRAY_TEX_UV][i].x==small[Mesh.ARRAY_TEX_UV][j].x,"Parent/child retained water")
	b.chunk_size=256
	var wet:Array=b.build_swamp_water(a,64);check(not wet.is_empty(),"Retained Coast pool water produced")
	for i in range(0,wet[Mesh.ARRAY_VERTEX].size(),97):
		check(wet[Mesh.ARRAY_COLOR][i].b==0,"Coast pools never receive Swamp flood stage")
		check(wet[Mesh.ARRAY_VERTEX][i].y==a[Mesh.ARRAY_TEX_UV][i].x,"Water uses same canonical elevations")
	var marine:Dictionary=manifest.features.underwater_cliff;var marine_arrays:Array=b.build(Vector2i(floori(marine.x/256),floori(marine.z/256)),64);var marine_water:Array=b.build_swamp_water(marine_arrays,64)
	if not marine_water.is_empty():
		for index:int in marine_water[Mesh.ARRAY_INDEX]:check(marine_water[Mesh.ARRAY_VERTEX][index].y>.2,"Ocean owns all marine water; no duplicate coastal sea grid")
	for name:String in ["tide_pools","connected_pools"]:
		var p:Dictionary=manifest.features[name];var h:float=b._get_height(p.x,p.z);check(h<b._last_swamp_water-.05 and b._last_swamp_water>.2,"Actual flooded rock depression")
	var stack:Dictionary=manifest.features.isolated_stack;var h:float=b._get_height(stack.x,stack.z)
	check(h>20 and b._coast.state[6]< -100,"Actual offshore heightfield remnant")
	if FileAccess.file_exists("res://tools/rocky_coast/baseline/builder.gd"):
		for kind in range(7):
			var current=builder();current.settings.rocky_coast_enabled=false
			for k in range(6):current.settings.set(["grass","forest","savanna","swamp","jungle","mountain"][k]+"_coverage",100 if kind==k or kind==6 else 0)
			current._configure_noise();var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/builder.gd").new();old.settings=current.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			for point:Vector2i in [Vector2i(21,17),cell]:check(current.build(point,16)==old.build(point,16),"Coast disabled preserves complete six-biome mesh arrays")
	FileAccess.open("res://tools/rocky_coast/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":true,"elapsed_s":float(Time.get_ticks_msec()-start)/1000,"collision":"not installed"},"\t"));print("ROCKY_COAST_INVARIANTS_PASS ",checks);quit()
