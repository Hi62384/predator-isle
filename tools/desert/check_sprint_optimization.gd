extends SceneTree
## Same-process exact-output and paired timing checks for the current source edit.
## "Before" is the sprint sampler before the allocation edit, not original terrain.
const Before = preload("res://tools/desert/sprint_baseline_20261014/desert_sampler.gd")
const After = preload("res://scripts/desert_sampler.gd")
var failures: Array[String] = []
var comparisons: int = 0

func state(s: RefCounted, x: float, z: float) -> Array:
	var h: float = s.sample(x,z)
	return [h,s.control_region,s.control_surface,s.control_wind,s.last_family,s.last_region,
		s.last_fan,s.last_crest,s.last_weights.duplicate()]

func sweep(s: RefCounted, origin: Vector2, side: int, step: float) -> Dictionary:
	var checksum: float = 0.0
	var start: int = Time.get_ticks_usec()
	for z in range(side):
		for x in range(side):
			checksum += s.sample(origin.x+x*step,origin.y+z*step)
	return {"microseconds":Time.get_ticks_usec()-start,"checksum":checksum}

func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size()/2])

func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	for seed_number in [73921,12345,90317]:
		for occupancy in [1.0,0.35,0.0]:
			var config := DesertSettings.new()
			config.dune_occurrence=occupancy
			config.canyon_occurrence=occupancy
			config.dry_lake_occurrence=occupancy
			var before = Before.new()
			var after = After.new()
			before.configure(config,seed_number)
			after.configure(config.duplicate(true),seed_number)
			for i in range(2048):
				var x: float = float((i*3793)%211)*737.0-77553.25
				var z: float = float((i*1913)%227)*641.0-70291.75
				comparisons += 1
				if state(before,x,z)!=state(after,x,z):
					failures.append("Exact height/control mismatch seed=%d occurrence=%s sample=%d" % [seed_number,str(occupancy),i])
					break
	var benchmarks: Array = []
	for item in [
		["sand_sea",Vector2(-4608,8960),65,4.0],
		["canyon",Vector2(18432,29440),65,4.0],
		["rocky_plain",Vector2(-53760,-34048),65,4.0],
		["far_1024m_step",Vector2(0,16384),17,1024.0]]:
		var before_cold: Array = []
		var after_cold: Array = []
		var before_warm: Array = []
		var after_warm: Array = []
		for repetition in range(7):
			var checksums: Array = []
			# Alternate order to reduce consistent first/second-process bias.
			for is_after in ([false,true] if repetition%2==0 else [true,false]):
				var sampler = After.new() if is_after else Before.new()
				sampler.configure(DesertSettings.new(),73921)
				var cold := sweep(sampler,item[1],item[2],item[3])
				var warm := sweep(sampler,item[1],item[2],item[3])
				checksums.append([cold.checksum,warm.checksum])
				if is_after:
					after_cold.append(cold.microseconds)
					after_warm.append(warm.microseconds)
				else:
					before_cold.append(cold.microseconds)
					before_warm.append(warm.microseconds)
			if checksums[0]!=checksums[1]:
				failures.append("Timing sweep changed canonical output: "+str(item[0]))
		benchmarks.append({"case":item[0],"origin":[item[1].x,item[1].y],"queries":item[2]*item[2],"step_m":item[3],
			"before_cold_us":before_cold,"after_cold_us":after_cold,
			"before_warm_us":before_warm,"after_warm_us":after_warm,
			"median_cold_ratio":median(after_cold)/maxf(median(before_cold),1.0),
			"median_warm_ratio":median(after_warm)/maxf(median(before_warm),1.0)})
	var report := {"engine":Engine.get_version_info().string,"os":OS.get_name(),
		"scope":"Paired uninstrumented sampling against the sprint sampler before the allocation edit. This is not the original simple-Desert CPU target, mesh/streaming cost or visual acceptance.",
		"comparisons":comparisons,"benchmarks":benchmarks,"failures":failures,
		"elapsed_s":(Time.get_ticks_usec()-started)/1000000.0}
	FileAccess.open("res://tools/desert/current_sprint_optimization.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
