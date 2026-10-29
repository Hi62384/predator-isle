extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const PrivateNetwork=preload("res://tools/caves/cave_network_candidate.gd")
const PrivateField=preload("res://tools/caves/cave_field_candidate.gd")
const PrivateMesher=preload("res://tools/caves/cave_gradient_mesher_candidate.gd")
const Payload=preload("res://scripts/caves/surface_payload.gd")
const PrivatePayload=preload("res://tools/caves/cave_surface_payload_candidate.gd")
const SurfaceShader=preload("res://scripts/caves/surface_shader.gd")
const PrivateSurfaceShader=preload("res://tools/caves/cave_surface_shader_candidate.gd")
func digest(value)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func run()->void:
	var guards:Dictionary={}
	for name:String in ["route_solver","network","field","mesher","surface_payload","surface_shader","cave_settings","surface_cut"]:
		var path:String="res://scripts/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	for name:String in ["cave_network_candidate","cave_route_solver_candidate","cave_field_candidate","cave_mesher_candidate","cave_gradient_mesher_candidate","cave_surface_payload_candidate","cave_surface_shader_candidate","check_production_core"]:
		var path:String="res://tools/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var p=make_builder(3,73921);var n=Network.new();n.configure(b._get_height,b.get_water_surface_height,73921);n.activity=1;var previous=PrivateNetwork.new();previous.configure(p._get_height,p.get_water_surface_height,73921);previous.activity=1;var data:Dictionary=n.region(Vector2i(9,-3));var expected:Dictionary=previous.region(Vector2i(9,-3));check(data.valid and data.nodes.size()==17 and data.edges.size()==20 and digest(data)==digest(expected),"Actual production core keeps the complete repaired original17node20edge graph exactly")
	var field=Field.new();var reference=PrivateField.new();check(field.compile([data],b._get_height) and reference.compile([expected],p._get_height),"Independent initially cold production/private field instances compile")
	var records:Array=[]
	for key:Vector3i in [Vector3i(231,0,-63),Vector3i(232,-1,-61),Vector3i(229,-2,-59),Vector3i(227,-2,-62)]:
		var a:Array=Mesher.new().build(field,key,2);var r:Array=PrivateMesher.new().build(reference,key,2);check(not a.is_empty() and digest(a)==digest(r),"Complete production mesh arrays exactly match repaired sign-case reference at actual previously problematic cell");records.append({"key":str(key),"complete_arrays_sha256":digest(a),"vertices":a[Mesh.ARRAY_VERTEX].size()});await process_frame
	var arrays:Array=b.build(Vector2i(58,-17),8)
	for i in range(81):check(Payload.decode(arrays,i,true)==PrivatePayload.decode(arrays,i,true),"Every production decoded material component repeats GPU-tested private implementation")
	var source:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader");check(SurfaceShader.code(source)==PrivateSurfaceShader.code(source),"Complete alternate production material shader exactly repeats GPU-tested source")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable production core source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_production_core.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"mesh_records":records,"production_runtime_enabled":false,"scope":"Production namespace migration of tested numeric cave core,sign-case mesher and decoded material transport. Original actual Spore graph and four previously problematic physical mesh cells match repaired private reference exactly. Runtime registration remains disabled;not live portals or sparse streaming acceptance."},"  "));print("PRODUCTION_CAVE_CORE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
