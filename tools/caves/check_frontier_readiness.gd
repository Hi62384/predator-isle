extends "res://tools/biome_extensions/check_all.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/streamer.gd","res://scripts/caves/cave_settings.gd",get_script().resource_path]:guards[path]=FileAccess.get_sha256(path)
	var stream=Streamer.new();stream.configuration=Config.new();stream._cells[Vector3i.ZERO]=null
	for axis in range(3):
		for sign_value:int in [-1,1]:
			var offset:=Vector3i.ZERO;offset[axis]=sign_value;var point:=Vector3(32,32,32);point[axis]=1 if sign_value<0 else 63;stream._wanted={offset:true}
			check(not stream.traversal_ready(point),"Approaching missing wanted neighbour pauses before physical cap on axis/sign")
			check(stream.traversal_ready(Vector3(32,32,32)),"Missing distant neighbour does not stall supported cell interior")
			stream._cells[offset]=null;check(stream.traversal_ready(point),"Known uploaded neighbour opens seam readiness");stream._cells.erase(offset);stream.configuration.seal_stream_frontiers=false;check(stream.traversal_ready(point),"Independent off setting restores original current-cell readiness exactly");stream.configuration.seal_stream_frontiers=true
	stream.free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable seam readiness source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frontier_readiness.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"scope":"All six approaching cell faces,queued versus known neighbour,cell-center no-stall and exact independent off readiness controls. Physical/actual live streaming proofs separate."},"  "));print("FRONTIER_READINESS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
