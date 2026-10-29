extends "res://tools/biome_extensions/check_all.gd"
const Partition=preload("res://scripts/terrain_partition.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/terrain_partition.gd","res://scripts/chunk_terrain.gd","res://scripts/caves/streamer.gd","res://tools/caves/check_detail_reservation.gd"]:guards[path]=FileAccess.get_sha256(path)
	var planner=Partition.new();planner.maximum_level=6;planner.split_ratio=.95;planner.merge_ratio=1.30;var point:=Vector2(14947.27,-4396.461);var original:Dictionary=planner.select(point,{});var baseline=Partition.new();baseline.maximum_level=6;baseline.split_ratio=.95;baseline.merge_ratio=1.30
	check(original==baseline.select(point,{}),"Empty reservation retains complete original distance-only partition")
	# A deliberately distant but still in-root reservation demonstrates real
	# recursive splitting,not only an override to one camera leaf's resolution.
	var reservations:Array[Rect2]=[Rect2(Vector2(16832,-4352),Vector2(256,256)),Rect2(Vector2(14784,-4480),Vector2(256,256))];planner.forced_detail_regions=reservations
	var leaves:Dictionary=planner.select(point,original);var keys:Array=leaves.keys();var area:float=0;var fine:int=0
	for i in range(keys.size()):
		var key:Vector3i=keys[i];var bounds:Rect2=planner.bounds(key);area+=bounds.get_area()
		if planner.reserved(key):fine+=1;check(key.z==0,"Every intersecting reserved parent reaches genuine LOD0")
		for j in range(i+1,keys.size()):
			check(not bounds.intersects(planner.bounds(keys[j])),"No overlapping reservation cut leaves")
			check(not planner.adjacent(key,keys[j]) or absi(key.z-keys[j].z)<=1,"Reservations retain balanced LOD edges")
	check(fine>=5 and keys.size()<512,"Positive complete bounded reservation,not a no-op or global fine tessellation")
	check(is_equal_approx(area,9.0*pow(planner.base_size*float(1<<planner.maximum_level),2)),"Exact original nine-root world coverage retained")
	planner.forced_detail_regions.clear();var restored:Dictionary=planner.select(point,{});check(restored==original,"Removing reservation restores complete original plan from same prior cut")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable reservation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_detail_reservation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"reserved_lod0_leaves":fine,"total_leaves":keys.size(),"scope":"Actual partition reservation policy:empty identity,recursive distant split,complete fine coverage,nonoverlap,balanced neighbors,unchanged total root area,and removal identity. Live portal/render/native walking has a separate gate."},"  "));print("CAVE_DETAIL_RESERVATION ",checks," fine=",fine," leaves=",keys.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
