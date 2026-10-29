extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func make_builder(seed_value:int=73921,jungle:float=100):
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.mountain_coverage=0;b.world_seed=seed_value
	b.settings.forest_coverage=0;b.settings.swamp_coverage=0;b.settings.savanna_coverage=0;b.settings.grass_coverage=100-jungle;b.settings.jungle_coverage=jungle;b.settings.temperature_enabled=false;b._configure_noise();return b
func _initialize()->void:
	var start:int=Time.get_ticks_msec()
	for seed_value in [73921,17,92881]:
		var b=make_builder(seed_value);var values:Array=[];var points:Array[Vector2]=[]
		for i in range(180):
			var p:=Vector2((i*7139)%80000-40000,(i*11939)%80000-40000);points.append(p)
			var h:float=b._sample_grid_height(p.x,p.y);var payload:float=b._last_jungle;values.append([h,payload])
			check(is_finite(h),"Finite height")
			check(payload==floorf(payload) and payload>=0 and payload<=16777215,"Exact 24-bit controls")
			check(h==b._get_height(p.x,p.y,false),"Height-only equality")
		b._height_grid_cache.clear();b._jungle._nodes.clear();b._jungle._regions.clear()
		for i in range(points.size()-1,-1,-1):
			var p:Vector2=points[i];var h:float=b._sample_grid_height(p.x,p.y)
			check(h==values[i][0] and b._last_jungle==values[i][1],"Cache/order independence")
		for i in range(30):
			var x:float=i*64-960;var z:float=i*41.7
			var a:float=b._jungle.sample(x-.01,z);var c:float=b._jungle.sample(x,z);var d:float=b._jungle.sample(x+.01,z)
			check(absf(d-a)<1 and absf(d-c-(c-a))<.03,"C1 canonical knots")
		var coordinate:=Vector2i.ZERO
		for p in points:
			if b._island_mask(p.x,p.y)>.05:coordinate=Vector2i(floori(p.x/256),floori(p.y/256));break
		var dense:Array=b.build(coordinate,64);var sparse:Array=b.build(coordinate,16);var neighbor:Array=b.build(coordinate+Vector2i.RIGHT,64)
		check(dense[Mesh.ARRAY_CUSTOM0].size()==dense[Mesh.ARRAY_VERTEX].size()*4,"RGBA controls uploaded")
		for z in range(17):
			for x in range(17):
				var a:int=z*17+x;var d:int=z*4*65+x*4
				check(dense[Mesh.ARRAY_VERTEX][d]==sparse[Mesh.ARRAY_VERTEX][a],"Shared LOD height")
				check(dense[Mesh.ARRAY_NORMAL][d].distance_to(sparse[Mesh.ARRAY_NORMAL][a])<.00001,"Shared LOD normal")
				for c in range(4):check(dense[Mesh.ARRAY_CUSTOM0][d*4+c]==sparse[Mesh.ARRAY_CUSTOM0][a*4+c],"Shared LOD controls")
		for z in range(65):
			var left:Vector3=dense[Mesh.ARRAY_VERTEX][z*65+64];var right:Vector3=neighbor[Mesh.ARRAY_VERTEX][z*65];right.x+=256
			check(left==right,"Adjacent chunk seam")
		b.settings.water_enabled=false;b._configure_noise()
		for p in points:
			b._get_height(p.x,p.y);check(b._jungle.river==0 and b._jungle.lake==0,"Water disabled")
		check(b._jungle._nodes.size()<=16384 and b._jungle._regions.size()<=2048,"Bounded sampler caches")
	# Fifth biome respects total mass and leaves legacy owner labels intact.
	var mixed=make_builder(73921,50);var found:Dictionary={}
	for i in range(500):
		var p:=Vector2((i*7919)%100000-50000,(i*11939)%100000-50000);var w:Vector4=mixed._biome_weights(p.x,p.y)
		check(absf(w.x+w.y+w.z+w.w+mixed._jungle_weight-1)<.00001,"Five-biome mass conservation")
		found[4 if mixed._jungle_weight>.5 else 0]=true
	check(found.size()==2,"Jungle and Grass assigned distinct regions")
	var report:Dictionary={"checks":checks,"failures":failures,"elapsed_s":float(Time.get_ticks_msec()-start)/1000,"active_biomes":["Grass","Jungle"]}
	var file:=FileAccess.open("res://tools/jungle/artifacts/invariants.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));print("JUNGLE_INVARIANTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
