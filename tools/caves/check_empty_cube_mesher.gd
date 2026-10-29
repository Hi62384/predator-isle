extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Portal=preload("res://scripts/caves/portal_field.gd")
const Network=preload("res://scripts/caves/network.gd")
const Reference=preload("res://scripts/caves/mesher.gd")
const Candidate=preload("res://tools/caves/empty_cube_mesher_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/network.gd","res://scripts/caves/route_solver.gd","res://tools/caves/empty_cube_mesher_candidate.gd","res://tools/caves/check_empty_cube_mesher.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1;var region:Dictionary=network.region(Vector2i(9,-3));var field=Field.new();check(field.compile([region],b._get_height),"Original actual cave field")
	var records:Array=[];var old_usec:int=0;var new_usec:int=0
	for key:Vector3i in [Vector3i(231,0,-63),Vector3i(232,-1,-61),Vector3i(229,-2,-59),Vector3i(227,-2,-62),Vector3i(231,-1,-64),Vector3i(230,-4,-63),Vector3i(233,0,-69),Vector3i(100,20,100)]:
		for step:float in [2.0,4.0]:
			var began:int=Time.get_ticks_usec();var original:Array=Reference.new().build(field,key,step);old_usec+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec();var candidate:Array=Candidate.new().build(field,key,step);new_usec+=Time.get_ticks_usec()-began;check(var_to_bytes(original)==var_to_bytes(candidate),"Every array exact,including empty/previously problematic cells and2m/4m lattices");records.append({"key":str(key),"step":step,"vertices":candidate[Mesh.ARRAY_VERTEX].size() if not candidate.is_empty() else 0});await process_frame
	var portal=Portal.new();check(portal.compile([region],b._get_height),"Actual surface/cave union comparison field")
	for key:Vector3i in [Vector3i(233,1,-69),Vector3i(232,1,-69),Vector3i(233,0,-69)]:
		check(var_to_bytes(Reference.new().build(portal,key,2))==var_to_bytes(Candidate.new().build(portal,key,2)),"Full actual portal field arrays retain exactly the same samples and output")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable empty-cube source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_empty_cube_mesher.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"reference_usec":old_usec,"candidate_usec":new_usec,"scope":"Exact same scalar samples/tetrahedra/order/winding/normals;only skip allocating per-cube temporary arrays for uniform signs. Complete array comparisons over original actual problematic,empty,2m/4m and surface-union cells. One ordered contended timing characterization,not isolated or universal performance certification."},"  "));print("CAVE_EMPTY_CUBE_MESHER ",checks," reference_usec=",old_usec," candidate_usec=",new_usec," failures=",failures);quit(0 if failures.is_empty() else 1)
