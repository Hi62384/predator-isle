extends SceneTree
const Collision=preload("res://scripts/terrain_collision.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func fixture(steep:bool)->Array:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	for z in range(9):
		for x in range(9):vertices.append(Vector3(x,x*20+z*30 if steep else 0,z))
	# Deliberate non-walking dummy skirt after the original 81 grid vertices.
	vertices.append(Vector3(0,-1000,0))
	for z in range(8):
		for x in range(8):
			var a:int=z*9+x;indices.append_array(PackedInt32Array([a,a+1,a+9,a+1,a+10,a+9]))
	indices.append_array(PackedInt32Array([0,81,1]))
	var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_INDEX]=indices;return result
func _initialize()->void:call_deferred("run")
func run()->void:
	var source:String=FileAccess.get_sha256("res://scripts/terrain_collision.gd")
	var flat:Array=fixture(false);var steep:Array=fixture(true)
	var flat_data:Dictionary=Collision.prepare(flat,8,true,[],{});var steep_data:Dictionary=Collision.prepare(steep,8,true,[],{})
	check(flat_data.ground_faces.is_empty() and flat_data.heightfield_error_bound_m<.01,"Flat terrain retains the compact heightfield")
	check(steep_data.ground_faces.size()==8*8*6 and steep_data.heightfield_error_bound_m>.01,"Steep terrain gets exact original surface triangles")
	var skirts_excluded:bool=true
	for v:Vector3 in steep_data.ground_faces:skirts_excluded=skirts_excluded and v.y>=0
	check(skirts_excluded,"Visual skirt is excluded from walking collision")
	var distant:Dictionary=Collision.prepare(steep,8,false,[],{})
	check(distant.heights.is_empty() and distant.ground_faces.is_empty(),"No terrain-collision allocation for distant-only meshes")
	var nodes:Array[MeshInstance3D]=[];var expected_arrays:Array=[flat,steep,steep]
	for case_id in range(3):
		var data:Dictionary=Collision.prepare(expected_arrays[case_id],8,true,[],{})
		if case_id==2:data.ground_faces=PackedVector3Array() # deliberate old-path negative control
		var node:=MeshInstance3D.new();node.mesh=ArrayMesh.new();node.mesh.set_meta("collision_data",data);node.position.x=case_id*50;root.add_child(node);nodes.append(node)
		Collision.stage(node,8,8,true)
		var body:StaticBody3D=node.get_node("NearTerrainCollision");var shape:Shape3D=body.get_node("Heightfield").shape
		check(body.collision_layer==0,"Prepared precision collider remains inactive before cut commit")
		check(shape is ConcavePolygonShape3D if case_id==1 else shape is HeightMapShape3D,"Selective shape type "+str(case_id))
		Collision.activate(node,true)
	for i in range(3):await physics_frame
	var records:Array=[];var negative_error:float=0
	for case_id in range(3):
		var node:MeshInstance3D=nodes[case_id];var vertices:PackedVector3Array=expected_arrays[case_id][Mesh.ARRAY_VERTEX];var maximum_error:float=0
		for z in range(1,8):
			for x in range(1,8):
				var vertex:Vector3=vertices[z*9+x]+node.global_position
				var query:=PhysicsRayQueryParameters3D.create(vertex+Vector3.UP*1000,vertex-Vector3.UP*1000,1)
				var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty():check(false,"Missing fixture ray "+str(case_id));continue
				var error:float=absf(hit.position.y-vertex.y);maximum_error=maxf(maximum_error,error)
				if case_id!=2:check(error<.02,"Precision collider follows the actual surface vertex")
		records.append({"fixture":case_id,"maximum_height_error_m":maximum_error,"old_heightfield_negative_control":case_id==2})
		if case_id==2:negative_error=maximum_error
		Collision.release(node);check(node.get_node("NearTerrainCollision").collision_layer==0 and node.get_node("NearTerrainCollision/Heightfield").shape==null,"Released shape is disabled and cleared")
	check(negative_error>.02,"Old steep heightfield negative control actually detects compression error")
	assert(FileAccess.get_sha256("res://scripts/terrain_collision.gd")==source,"Collision source changed during test")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"records":records,"negative_control_detected":negative_error>.02,"source_sha256":{"res://scripts/terrain_collision.gd":source,"res://tools/badlands/check_collision_precision.gd":FileAccess.get_sha256("res://tools/badlands/check_collision_precision.gd")},"scope":"Synthetic native Jolt selectivity, exact triangle/skirt exclusion, stage/release lifecycle, 98 positive vertex rays and 49 deliberate old-heightfield control rays. Separate from production-landmark and capsule-route evidence."}
	FileAccess.open("res://tools/badlands/artifacts/check_collision_precision.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("COLLISION_PRECISION ",checks," checks; old-path error=",negative_error,"; failures=",failures)
	for node:MeshInstance3D in nodes:node.queue_free()
	await process_frame;quit(0 if failures.is_empty() else 1)
