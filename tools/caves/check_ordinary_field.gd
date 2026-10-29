extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Portal=preload("res://scripts/caves/portal_field.gd")
const Ordinary=preload("res://tools/caves/ordinary_field_candidate.gd")
const Mesher=preload("res://scripts/caves/portal_mesher.gd")
const Fast=preload("res://tools/caves/empty_cube_mesher_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/portal_mesher.gd","res://scripts/caves/network.gd","res://scripts/caves/route_solver.gd","res://tools/caves/ordinary_field_candidate.gd","res://tools/caves/check_ordinary_field.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var n=Network.new();n.configure(b._get_height,b.get_water_surface_height,73921);n.activity=1;var region:Dictionary=n.region(Vector2i(9,-3));var original=Portal.new();var candidate=Ordinary.new();check(original.compile([region],b._get_height) and candidate.compile([region],b._get_height),"Same complete original actual graph in independent union/ordinary fields")
	var old_usec:int=0;var new_usec:int=0;var records:Array=[]
	for key:Vector3i in [Vector3i(231,0,-63),Vector3i(232,-1,-61),Vector3i(229,-2,-59),Vector3i(227,-2,-62),Vector3i(231,-3,-63),Vector3i(230,-4,-63)]:
		var began:int=Time.get_ticks_usec();var a:Array=Mesher.new().build(original,key,2);old_usec+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec();var c:Array=Mesher.new().build(candidate,key,2);new_usec+=Time.get_ticks_usec()-began;check(var_to_bytes(a)==var_to_bytes(c),"Complete buried-cell arrays remain exact without unnecessary overlying surface union");records.append({"key":str(key),"vertices":c[Mesh.ARRAY_VERTEX].size() if not c.is_empty() else 0});await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable ordinary-field source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_ordinary_field.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"reference_usec":old_usec,"candidate_usec":new_usec,"scope":"Actual original buried cells:complete arrays against prior surface-union implementation,with unchanged canonical clipping/normal samples. Ordinary volume avoids unrelated surface extraction. Explicit portal field remains unchanged. One ordered contended timing,not general startup or frame-performance proof."},"  "));print("CAVE_ORDINARY_FIELD ",checks," reference_usec=",old_usec," candidate_usec=",new_usec," failures=",failures);quit(0 if failures.is_empty() else 1)
