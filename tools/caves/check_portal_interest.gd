extends "res://tools/biome_extensions/check_all.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/streamer.gd","res://scripts/caves/cave_settings.gd"]:guards[path]=FileAccess.get_sha256(path)
	var stream=Streamer.new();stream.configuration=Config.new();var cases:int=0;var unnecessary:int=0;var needed:int=0;var mismatches:int=0;var records:Array=[]
	for offset:float in [0,20000,-20000]:
		var entrance:Dictionary={"point":Vector3(offset,120,-offset),"minimum_exposed_floor":108.0,"columns":{Vector2i(floori(offset/64),floori(-offset/64)):true}};stream._bundle={"entrances":[entrance]}
		for below:float in [-100,-1,0,15.99,16,16.01,30,100,260,400]:
			for horizontal:float in [0,64,255.99,256,256.01,300]:
				var point:Vector3=Vector3(offset+horizontal,108-below,-offset);var original_required:bool=not(point.y<108.0-16.0 or point.distance_to(entrance.point)>256.0);var actual:bool=stream.entrance_needed(entrance,point);var columns:Dictionary=stream.nearby_columns(point);var old_xy:bool=horizontal<=256.0;cases+=1
				if actual!=original_required or (not columns.is_empty())!=original_required:mismatches+=1
				if old_xy and not original_required:unnecessary+=1
				if original_required:needed+=1
				records.append({"offset_m":offset,"below_exposed_floor_m":below,"horizontal_m":horizontal,"original_readiness_required":original_required,"new_extraction_requested":not columns.is_empty(),"old_xy_extraction_requested":old_xy})
	check(cases==180 and mismatches==0 and needed>0 and unnecessary>0,"Exact ORIGINAL three-dimensional readiness envelope retained for every case;only unnecessary XY-only extractions removed")
	# Missing optional measured floor retains the exact original point.y
	# fallback,including the original inclusive lower and distance boundaries.
	var entrance:Dictionary={"point":Vector3.ZERO,"columns":{Vector2i.ZERO:true}};stream._bundle={"entrances":[entrance]}
	check(stream.entrance_needed(entrance,Vector3(0,-16,0)) and not stream.entrance_needed(entrance,Vector3(0,-16.001,0)),"Unmeasured-floor fallback and inclusive original16m floor envelope")
	check(stream.entrance_needed(entrance,Vector3(256,0,0)) and not stream.entrance_needed(entrance,Vector3(256.01,0,0)),"Original inclusive256m three-dimensional preload boundary")
	stream.free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable shared original portal-interest source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_portal_interest.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"needed_extraction_cases":needed,"unnecessary_xy_only_cases":unnecessary,"readiness_mismatches":mismatches,"scope":"Original traversal_ready's EXISTING exposed-floor-minus2headrooms and3D256m conditions shared verbatim with nearby_columns extraction.180signed/vertical/horizontal boundary cases plus missing-floor fallback. No smaller readiness envelope,changed player/route/geometry/worker limit,overworld hiding or full-live/FPS claim. OldXY-only staging positives below the original support envelope demonstrate removed unnecessary portal work."},"  "));print("PORTAL_INTEREST ",checks," cases=",cases," unnecessary=",unnecessary," required=",needed," mismatches=",mismatches," failures=",failures);quit(0 if failures.is_empty() else 1)
