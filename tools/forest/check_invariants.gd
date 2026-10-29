extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func builder(seed_value:int=73921,forest:float=100,grass:float=0,jungle:float=0):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.mountain_coverage=0;b.world_seed=seed_value
	b.settings.swamp_coverage=0;b.settings.savanna_coverage=0;b.settings.grass_coverage=grass;b.settings.jungle_coverage=jungle;b.settings.forest_coverage=forest;b._configure_noise();return b
func _initialize()->void:
	var tick:int=Time.get_ticks_msec()
	for seed_value in [73921,17,92881]:
		var b=builder(seed_value);var points:Array[Vector2]=[];var values:Array=[]
		for i in range(160):
			var p:=Vector2((i*7919)%120000-60000,(i*11939)%120000-60000);points.append(p)
			var h:float=b._sample_grid_height(p.x,p.y);var controls:PackedFloat32Array=b._last_forest;values.append([h,controls])
			check(is_finite(h),"Finite height")
			for k in range(2):check(controls[k]==floorf(controls[k]) and controls[k]>=0 and controls[k]<=16777215,"Exact float24 controls")
			check(h==b._get_height(p.x,p.y,false),"Height-only equality")
		b._height_grid_cache.clear();b._forest._nodes.clear();b._forest._regions.clear()
		for i in range(points.size()-1,-1,-1):
			var p:Vector2=points[i];var h:float=b._sample_grid_height(p.x,p.y)
			check(h==values[i][0] and b._last_forest==values[i][1],"Cache eviction / reverse order")
		for i in range(30):
			var x:float=i*64-960;var z:float=i*41.7;var s=b._forest
			var a:float=s.sample(x-.01,z);var c:float=s.sample(x,z);var d:float=s.sample(x+.01,z)
			check(absf(d-a)<1 and absf(d-c-(c-a))<.03,"C1 canonical lattice")
		var coordinate:=Vector2i.ZERO
		for p in points:
			if b._island_mask(p.x,p.y)>.05:coordinate=Vector2i(floori(p.x/256),floori(p.y/256));break
		var dense:Array=b.build(coordinate,64);var sparse:Array=b.build(coordinate,16);var neighbor:Array=b.build(coordinate+Vector2i.RIGHT,64)
		check(dense[Mesh.ARRAY_CUSTOM1].size()==dense[Mesh.ARRAY_VERTEX].size()*4,"Forest RGBA payload exists")
		for z in range(17):
			for x in range(17):
				var a:int=z*17+x;var d:int=z*4*65+x*4
				check(dense[Mesh.ARRAY_VERTEX][d]==sparse[Mesh.ARRAY_VERTEX][a],"Shared LOD height")
				check(dense[Mesh.ARRAY_NORMAL][d].distance_to(sparse[Mesh.ARRAY_NORMAL][a])<.00001,"Shared LOD normal")
				for c in range(4):check(dense[Mesh.ARRAY_CUSTOM1][d*4+c]==sparse[Mesh.ARRAY_CUSTOM1][a*4+c],"Shared LOD controls")
		for z in range(65):
			var p:Vector3=dense[Mesh.ARRAY_VERTEX][z*65+64];var q:Vector3=neighbor[Mesh.ARRAY_VERTEX][z*65];q.x+=256;check(p==q,"Adjacent chunk seam")
		b.settings.water_enabled=false;b._configure_noise()
		for p in points:b._get_height(p.x,p.y);check(b._forest.river==0 and b._forest.lake==0,"Water disabled")
		check(b._forest._nodes.size()<=16384 and b._forest._regions.size()<=2048,"Bounded caches")
	var mixed=builder(73921,40,30,30);var owners:Dictionary={}
	mixed.settings.grass_region_size=8000;mixed._configure_noise()
	for i in range(1200):
		var p:=Vector2((i*7919)%180000-90000,(i*11939)%180000-90000);var w:Vector4=mixed._biome_weights(p.x,p.y)
		check(w.z==0 and w.w==0 and absf(w.x+w.y+mixed._jungle_weight-1)<.00001,"Three-biome mass / no retired biomes")
		owners[4 if mixed._jungle_weight>maxf(w.x,w.y) else (1 if w.y>w.x else 0)]=true
	check(owners.size()==3,"All three biomes assigned")
	var baseline_available:bool=FileAccess.file_exists("res://tools/forest/baseline/builder.gd")
	if baseline_available:
		for kind in range(3):
			var b=builder(73921,0,100 if kind==0 else (0 if kind==1 else 50),100 if kind==1 else (0 if kind==0 else 50))
			var old=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/forest/baseline/builder.gd").new();old.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old._configure_noise()
			for point in [Vector2i.ZERO,Vector2i(81,-17),Vector2i(-193,48)]:check(b.build(point,16)==old.build(point,16),"Forest disabled: exact pre-change mesh arrays")
	var report:Dictionary={"checks":checks,"failures":failures,"elapsed_s":float(Time.get_ticks_msec()-tick)/1000,"pre_forest_snapshot":baseline_available,"scope":"Terrain only. No vegetation or collision system added."}
	FileAccess.open("res://tools/forest/artifacts/invariants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("FOREST_INVARIANTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
