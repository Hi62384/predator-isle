extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://tools/caves/cave_field_candidate.gd")
const Reference=preload("res://tools/caves/cave_mesher_candidate.gd")
const Candidate=preload("res://tools/caves/cave_gradient_mesher_candidate.gd")
func digest(arrays:Array)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(arrays));return h.finish().hex_encode()
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_gradient_mesher.gd","res://tools/caves/cave_field_candidate.gd","res://tools/caves/cave_mesher_candidate.gd","res://tools/caves/cave_gradient_mesher_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary={"valid":true,"nodes":[{"point":Vector3(0,-8,0),"level":0,"chamber_radius":14.0,"chamber_height":14.0}],"edges":[]}
	for pair:Array in [[Vector3(-40,-8,0),Vector3(40,-8,0)],[Vector3(0,-8,-40),Vector3(0,-8,40)],[Vector3(30,-8,0),Vector3(58,-13.6,0)]]:region.edges.append({"points":PackedVector3Array(pair),"half_width":4.0,"headroom":8.0,"entrance":false})
	var field=Field.new();assert(field.compile([region],func(_x:float,_z:float)->float:return 100));var records:Array=[];var reference_seconds:float=0;var candidate_seconds:float=0
	for z in [-1,0]:
		for y in [-1,0]:
			for x in [-1,0]:
				var key:=Vector3i(x,y,z);var pair:Dictionary={}
				for original:bool in ([true,false] if records.size()%2==0 else [false,true]):
					var start:int=Time.get_ticks_usec();var a:Array=(Reference.new() if original else Candidate.new()).build(field,key,2);pair[original]={"hash":digest(a),"seconds":(Time.get_ticks_usec()-start)/1000000.0,"vertices":a[Mesh.ARRAY_VERTEX].size() if not a.is_empty() else 0}
				check(pair[true].hash==pair[false].hash,"Complete original mesh arrays unchanged by tetrahedral orientation candidate "+str(key));reference_seconds+=pair[true].seconds;candidate_seconds+=pair[false].seconds;records.append({"cell":str(key),"reference":pair[true],"candidate":pair[false]})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable gradient source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_gradient_mesher.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"reference_seconds":reference_seconds,"candidate_seconds":candidate_seconds,"production_registration":false,"scope":"PRIVATE eight original synthetic joined-field cells,alternating extraction order; complete position/normal/color hashes,not only counts. Not actual-world/native/streaming acceptance or a repeated isolated speedup."},"  "));print("GRADIENT_MESHER ",checks," seconds=",reference_seconds,"/",candidate_seconds," failures=",failures);quit(0 if failures.is_empty() else 1)
