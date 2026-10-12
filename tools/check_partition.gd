extends SceneTree
func _initialize() -> void:
	var planner=load("res://scripts/terrain_partition.gd").new()
	planner.split_ratio=0.95
	planner.merge_ratio=1.30
	var previous: Dictionary={}
	for point in [Vector2.ZERO,Vector2(255,255),Vector2(-1,-1),Vector2(-8193,400),Vector2(40000,-10000),Vector2(40001,-10000)]:
		var leaves: Dictionary=planner.select(point,previous)
		var keys:=leaves.keys()
		assert(keys.size()<512,"Unbounded leaf count")
		var area:=0.0
		for i in range(keys.size()):
			var a: Rect2=planner.bounds(keys[i]);area+=a.get_area()
			for j in range(i+1,keys.size()):
				var b: Rect2=planner.bounds(keys[j])
				assert(not a.intersects(b),"Overlapping leaves")
				assert(not planner.adjacent(keys[i],keys[j]) or absi(keys[i].z-keys[j].z)<=1,"Unbalanced edge")
		assert(is_equal_approx(area,9.0*pow(planner.base_size*float(1<<planner.maximum_level),2)),"Coverage area mismatch")
		print("PARTITION ",point," leaves=",keys.size()," area=",area)
		previous=leaves
	print("PASS global alignment, full root coverage, no overlap and balanced edges")
	quit()
