extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://scripts/caves/network.gd")
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
func bodies_for(field,keys:Dictionary)->Array:
	var bodies:Array=[]
	for key:Vector3i in keys:
		var arrays:Array=Mesher.new().build(field,key,2)
		if arrays.is_empty():continue
		var body:=StaticBody3D.new();body.position=Vector3(key)*64;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);root.add_child(body);bodies.append(body)
	return bodies
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/network.gd","res://scripts/caves/workload.gd","res://scripts/caves/streamer.gd","res://tools/caves/check_entry_seal.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1;var region:Dictionary=network.region(Vector2i(9,-3));var field=Field.new();check(field.compile([region],b._get_height),"Original actual cave region")
	var points:PackedVector3Array=region.edges[0].points;var crossing:Dictionary={}
	for i in range(points.size()-1):
		var a:Vector3=points[i]+Vector3(0,.95,0);var c:Vector3=points[i+1]+Vector3(0,.95,0);field.opening_rock_cover=0
		if field.sample(a)>=0 or field.sample(c)>=0:continue
		field.opening_rock_cover=6
		if field.sample(a)>=0 and field.sample(c)<0:crossing={"inside":c,"outside":a};break
	check(not crossing.is_empty(),"Positive actual entry has a supported physical closed/open loading boundary")
	if not crossing.is_empty():
		# A sampled field sign immediately adjacent to zero is not itself a
		# promise of sub-grid extraction accuracy. Bracket the finite2m mesh
		# boundary on both sides instead of demanding an analytic-plan hit.
		var direction:Vector3=(crossing.outside-crossing.inside).normalized();crossing.inside-=direction*3;crossing.outside+=direction*3
		check(field.sample(crossing.inside)<0 and field.sample(crossing.outside)>0,"Finite-width independent solid/air ray bracket")
		var keys:Dictionary={field.cell(crossing.inside):true,field.cell(crossing.outside):true};var bodies:Array=await bodies_for(field,keys)
		for frame in range(3):await physics_frame
		var state:PhysicsDirectSpaceState3D=bodies[0].get_world_3d().direct_space_state;var query:=PhysicsRayQueryParameters3D.create(crossing.inside,crossing.outside);var sealed_hit:Dictionary=state.intersect_ray(query);check(not sealed_hit.is_empty(),"Native streamed geometry closes unfinished mouth instead of exposing an unsupported floor gap")
		for body:StaticBody3D in bodies:body.collision_layer=0;body.queue_free()
		field.opening_rock_cover=0;bodies=await bodies_for(field,keys)
		for frame in range(3):await physics_frame
		var open_hit:Dictionary=state.intersect_ray(query);check(open_hit.is_empty(),"Complete explicit portal mode removes the temporary rock seal on same exact route")
		for body:StaticBody3D in bodies:body.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable entrance seal source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_entry_seal.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"route_boundary":str(crossing),"scope":"Original actual entrance,same6mloading boundary:ordinary volume has real native closed seal;explicit completed portal mode unseals exactly the same route. Protects unloaded entrance approach instead of leaving a floor gap. Long live return acceptance is separate."},"  "));print("CAVE_ENTRY_SEAL ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
