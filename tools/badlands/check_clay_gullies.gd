extends SceneTree
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func make_builder(seed_id:int,secondary:float):
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=100;builder.settings.badlands.secondary_gullies=secondary;builder._configure_noise();return builder
func find_incisions(enabled,disabled)->Array:
	var found:Array=[]
	for lane in range(-20,21):
		for index in range(-72,73):
			for side in [-1,1]:
				var tree:Dictionary=enabled._badlands._tree(index,lane,side)
				for edge:Array in tree.edges:
					if edge[2]<2 or edge[2]>3:continue
					var point:Vector3=edge[0].lerp(edge[1],.5);var p:=Vector2(point.x,point.z)
					if enabled._island_mask(p.x,p.y)<.1:continue
					var weights:PackedFloat32Array=enabled._badlands.region_weights(p)
					if weights[2]+weights[3]<.9:continue
					var original:float=disabled._get_height(p.x,p.y);var carved:float=enabled._get_height(p.x,p.y)
					if original-carved<.5:continue
					check(is_finite(carved) and carved<original-.5,"Fine gullies actually incise low-relief inland clay")
					found.append({"position":p,"uncut":original,"carved":carved,"incision":original-carved})
					if found.size()>=6:return found
	return found
func _initialize()->void:
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var enabled=make_builder(seed_id,.75);var disabled=make_builder(seed_id,0)
		check(enabled.settings.badlands.secondary_gullies==.75 and disabled.settings.badlands.secondary_gullies==0,"Independent fixture configuration snapshots")
		print("CLAY_FIXTURE_SETTINGS ",enabled.settings.badlands.secondary_gullies," / ",disabled.settings.badlands.secondary_gullies)
		var found:Array=find_incisions(enabled,disabled)
		check(found.size()>=6,"Actual low-relief clay source incisions located")
		cases.append({"seed":seed_id,"incisions":found})
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":cases,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Enabled versus disabled connected secondary drainage at actual inland clay locations; not a hydraulic simulation"}
	FileAccess.open("res://tools/badlands/artifacts/check_clay_gullies.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_CLAY_GULLIES ",result);quit(0 if failures.is_empty() else 1)
