extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func builder(seed_value:int=73921,savanna:float=100,grass:float=0,jungle:float=0,forest:float=0):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.mountain_coverage=0;b.world_seed=seed_value
	b.settings.forest_coverage=forest;b.settings.grass_coverage=grass;b.settings.jungle_coverage=jungle;b.settings.swamp_coverage=0;b.settings.savanna_coverage=savanna;b._configure_noise();return b
func _initialize()->void:
	var tick:int=Time.get_ticks_msec()
	for seed_value in [73921,17,92881]:
		var b=builder(seed_value);var points:Array[Vector2]=[];var values:Array=[]
		for i in range(160):
			var p:=Vector2((i*7919)%120000-60000,(i*11939)%120000-60000);points.append(p)
			var h:float=b._sample_grid_height(p.x,p.y);var controls:PackedFloat32Array=b._last_savanna;values.append([h,controls])
			check(is_finite(h),"Finite height")
			for k in range(4):check(controls[k]==floorf(controls[k]) and controls[k]>=0 and controls[k]<=16777215,"Exact float24 controls")
			check(h==b._get_height(p.x,p.y,false),"Height-only equality")
		b._height_grid_cache.clear();b._savanna._nodes.clear();b._savanna._regions.clear();b._savanna._kopje_cache.clear()
		for i in range(points.size()-1,-1,-1):
			var p:Vector2=points[i];var h:float=b._sample_grid_height(p.x,p.y)
			check(h==values[i][0] and b._last_savanna==values[i][1],"Cache eviction / reverse order")
		for i in range(30):
			var x:float=i*32-480;var z:float=i*41.7;var s=b._savanna
			var a:float=s.sample(x-.01,z);var c:float=s.sample(x,z);var d:float=s.sample(x+.01,z)
			check(absf(d-a)<1 and absf(d-c-(c-a))<.03,"C1 canonical lattice")
		var coordinate:=Vector2i.ZERO
		for p in points:
			if b._island_mask(p.x,p.y)>.05:coordinate=Vector2i(floori(p.x/256),floori(p.y/256));break
		var dense:Array=b.build(coordinate,64);var sparse:Array=b.build(coordinate,16);var neighbor:Array=b.build(coordinate+Vector2i.RIGHT,64)
		check(dense[Mesh.ARRAY_CUSTOM2].size()==dense[Mesh.ARRAY_VERTEX].size()*4,"Savanna RGBA payload exists")
		for z in range(17):
			for x in range(17):
				var a:int=z*17+x;var d:int=z*4*65+x*4
				check(dense[Mesh.ARRAY_VERTEX][d]==sparse[Mesh.ARRAY_VERTEX][a],"Shared LOD height")
				check(dense[Mesh.ARRAY_NORMAL][d].distance_to(sparse[Mesh.ARRAY_NORMAL][a])<.00001,"Shared LOD normal")
				for c in range(4):check(dense[Mesh.ARRAY_CUSTOM2][d*4+c]==sparse[Mesh.ARRAY_CUSTOM2][a*4+c],"Shared LOD controls")
		for z in range(65):
			var p:Vector3=dense[Mesh.ARRAY_VERTEX][z*65+64];var q:Vector3=neighbor[Mesh.ARRAY_VERTEX][z*65];q.x+=256;check(p==q,"Adjacent chunk seam")
		var shape:Array=[]
		for p in points:shape.append([b._get_height(p.x,p.y),b._last_savanna])
		b.settings.savanna.season=1;b.settings.water_enabled=false;b._configure_noise()
		for i in range(points.size()):
			var p:Vector2=points[i];check(b._get_height(p.x,p.y)==shape[i][0] and b._last_savanna==shape[i][1],"Season and water rendering do not alter canonical shape/payload")
		check(b._savanna._nodes.size()<=16384 and b._savanna._regions.size()<=2048 and b._savanna._kopje_cache.size()<=1024,"Bounded caches")
	var mixed=builder(73921,25,25,25,25);var owners:Dictionary={}
	mixed.settings.grass_region_size=8000;mixed._configure_noise()
	for i in range(1200):
		var p:=Vector2((i*7919)%180000-90000,(i*11939)%180000-90000);var w:Vector4=mixed._biome_weights(p.x,p.y)
		check(w.w==0 and absf(w.x+w.y+w.z+mixed._jungle_weight-1)<.00001,"Four-biome mass / no retired biomes")
		var id:int=0
		for k in range(1,3):
			if w[k]>w[id]:id=k
		owners[4 if mixed._jungle_weight>w[id] else id]=true
	check(owners.size()==4,"All four biomes assigned")
	var dry=builder();dry.settings.savanna.perennial_frequency=0;dry.settings.savanna.basin_water_coverage=0;dry._configure_noise();var dry_beds:int=0
	for i in range(300):
		var p:=Vector2((i*7919)%120000-60000,(i*11939)%120000-60000);dry._get_height(p.x,p.y)
		check(dry._savanna.water==0,"Zero perennial/pool coverage disables all wet reaches")
		if dry._savanna.river>.1:dry_beds+=1
	check(dry_beds>0,"Dry channel geometry survives disabling wet reaches")
	var baseline_available:bool=FileAccess.file_exists("res://tools/savanna/baseline/builder.gd")
	if baseline_available:
		for kind in range(4):
			var b=builder(73921,0,100 if kind==0 else (0 if kind==1 else 50),100 if kind==1 else (0 if kind==0 else 50))
			if kind==3:b.settings.grass_coverage=0;b.settings.jungle_coverage=0;b.settings.forest_coverage=100;b._configure_noise()
			var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/savanna/baseline/builder.gd").new();old.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			for point in [Vector2i.ZERO,Vector2i(81,-17),Vector2i(-193,48)]:check(b.build(point,16)==old.build(point,16),"Savanna disabled: exact pre-change mesh arrays")
	var preopt_available:bool=FileAccess.file_exists("res://tools/savanna/baseline/savanna_preopt.gd")
	if preopt_available:
		var b=builder();var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/savanna/baseline/savanna_preopt.gd").new();old.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
		for i in range(500):
			var p:=Vector2((i*7919)%160000-80000,(i*11939)%160000-80000)
			check(b._get_height(p.x,p.y)==old._get_height(p.x,p.y) and b._last_savanna==old._last_savanna,"Conservative support culling / descriptor memo preserve exact height and controls")
		for p:Vector2i in [Vector2i.ZERO,Vector2i(-193,48)]:check(b.build(p,16)==old.build(p,16),"Optimized full Savanna mesh equals uncullled reference")
	var report:Dictionary={"checks":checks,"failures":failures,"elapsed_s":float(Time.get_ticks_msec()-tick)/1000,"pre_savanna_snapshot":baseline_available,"pre_optimization_snapshot":preopt_available,"scope":"Terrain only. No vegetation or collision system added."}
	FileAccess.open("res://tools/savanna/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SAVANNA_INVARIANTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
