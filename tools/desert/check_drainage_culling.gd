extends SceneTree
const Desert=preload("res://scripts/desert_sampler.gd")
class FullDrainage extends "res://scripts/desert_drainage.gd":
	func _local_candidates(p: Vector2, source: RefCounted) -> Array:
		return _nearby(Vector2i(floori(p.x/TILE),floori(p.y/TILE)),source)

func _initialize() -> void:
	var failures: Array=[];var rows: Array=[]
	for seed_value in [73921,12345,-90317]:
		var full=Desert.new();var culled=Desert.new()
		full._drainage_graph=FullDrainage.new()
		full.configure(DesertSettings.new(),seed_value);culled.configure(DesertSettings.new(),seed_value)
		var points: Array[Vector2]=[]
		for origin in [Vector2(18432,29440),Vector2(7680,27136),Vector2(22528,-5632),Vector2(-19968,35584)]:
			for z in range(45):
				for x in range(45):points.append(origin+Vector2(x*8.0,z*8.0))
		for edge in range(-20,21):
			for epsilon in [-0.01,0.0,0.01]:points.append(Vector2(edge*128.0+epsilon,edge*1024.0-epsilon))
		var reference: Array=[];var tick: int=Time.get_ticks_usec()
		for p in points:
			var h: float=full.sample(p.x,p.y)
			reference.append([h,full.control_surface,full.control_wind,full.control_detail])
		var full_us: int=Time.get_ticks_usec()-tick
		tick=Time.get_ticks_usec()
		for i in range(points.size()):
			var h: float=culled.sample(points[i].x,points[i].y)
			if [h,culled.control_surface,culled.control_wind,culled.control_detail]!=reference[i]:failures.append(str([seed_value,points[i]]))
		var culled_us: int=Time.get_ticks_usec()-tick
		for i in range(2300):culled.sample(i*129.0,i*-113.0)
		if culled._drainage_graph._local_tiles.size()>2048:failures.append("Unbounded drainage subtiles")
		for i in range(0,points.size(),31):
			if culled.sample(points[i].x,points[i].y)!=reference[i][0]:failures.append("Eviction changed drainage")
		rows.append({"seed":seed_value,"exact_samples":points.size(),"full_candidates_us":full_us,"culled_candidates_us":culled_us})
	var result: Dictionary={"failures":failures,"cases":rows,"note":"Exact heights and all dependent GPU controls, including 128/1024 m boundaries and cache eviction. Single-process timings are diagnostic, not a streaming claim."}
	FileAccess.open("res://tools/desert/drainage_culling_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
