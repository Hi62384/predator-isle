extends SceneTree
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func make_builder(seed_id:int,relief:float):
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=100;builder.settings.badlands.relief=relief;builder._configure_noise();return builder
func _initialize()->void:
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for relief:float in [.2,1,2]:
			var builder=make_builder(seed_id,relief);var field=builder._badlands
			var points:Array[Vector2]=[]
			for i in range(200):points.append(Vector2(i*7919%200000-100000,i*11939%200000-100000))
			# Also exercise conservative bin edges near real drainage roots/sources.
			for index in range(-2,3):
				var tree:Dictionary=field._tree(index,0,1)
				for point:Vector3 in [tree.root,tree.ends[0]]:
					var cell:=Vector2i(floori(point.x/256),floori(point.z/256))
					for offset:float in [-.01,0,.01]:points.append(Vector2(cell.x*256+offset,cell.y*256+offset))
			for p:Vector2 in points:
				field._use_segment_index=false;field._use_grade_bound=false;field._tree_radius_override=5;var expected:PackedFloat64Array=field._raw(p)
				field._use_segment_index=true;field._use_grade_bound=true;field._tree_radius_override=0;var actual:PackedFloat64Array=field._raw(p)
				check(actual==expected,"Indexed raw height and every control exactly match full segment scan")
			cases.append({"seed":seed_id,"relief":relief,"points":points.size()})
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":cases,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd")}
	FileAccess.open("res://tools/badlands/artifacts/check_segment_index.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_SEGMENT_INDEX ",result);quit(0 if failures.is_empty() else 1)
