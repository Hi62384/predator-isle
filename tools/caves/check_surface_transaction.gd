extends "res://tools/biome_extensions/check_all.gd"
const Transaction=preload("res://scripts/caves/surface_transaction.gd")
func patch(position:Vector3,altitude:float)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.visible=false;node.position=position;var faces:=PackedVector3Array([Vector3(0,altitude,0),Vector3(64,altitude,0),Vector3(0,altitude,64),Vector3(64,altitude,0),Vector3(64,altitude,64),Vector3(0,altitude,64)]);var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=faces;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh;var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=0;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);child.shape=shape;body.add_child(child);node.add_child(body);root.add_child(node);return node
func floor_at(node:Node3D,point:Vector2)->float:
	var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,30,point.y),Vector3(point.x,-10,point.y)));return hit.position.y if not hit.is_empty() else -INF
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/surface_transaction.gd","res://scripts/caves/surface_cut.gd","res://scripts/terrain_collision.gd","res://tools/caves/check_surface_transaction.gd"]:guards[path]=FileAccess.get_sha256(path)
	var parent:=MeshInstance3D.new();parent.position=Vector3(-64,0,-64);var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array();arrays[Mesh.ARRAY_INDEX]=PackedInt32Array();var heights:=PackedFloat32Array()
	for z in range(17):
		for x in range(17):arrays[Mesh.ARRAY_VERTEX].append(Vector3(x*8,20,z*8));heights.append(20)
	for z in range(16):
		for x in range(16):
			var a:int=z*17+x;arrays[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([a,a+1,a+17,a+1,a+18,a+17]))
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded;varying vec3 forest_local_position;void vertex(){forest_local_position=VERTEX;}\nvoid fragment() {ALBEDO=vec3(.4);}";var material:=ShaderMaterial.new();material.shader=shader;mesh.surface_set_material(0,material);mesh.set_meta("terrain_cpu_arrays",arrays);parent.mesh=mesh;parent.set_meta("resolution",16);parent.set_meta("tile",Vector3i.ZERO);root.add_child(parent)
	var body:=StaticBody3D.new();body.name="NearTerrainCollision";parent.add_child(body);var shape_node:=CollisionShape3D.new();shape_node.name="Heightfield";var shape:=HeightMapShape3D.new();shape.map_width=17;shape.map_depth=17;shape.map_data=heights;shape_node.shape=shape;shape_node.position=Vector3(64,0,64);shape_node.scale=Vector3(8,1,8);body.add_child(shape_node);var original_transform:Transform3D=shape_node.transform;var original_rid:RID=shape.get_rid()
	var first_patch:MeshInstance3D=patch(Vector3(-64,0,-64),10);var first=Transaction.new()
	for frame in range(3):await physics_frame
	check(absf(floor_at(parent,Vector2(-32,-32))-20)<.03,"Original complete native heightfield initially supports the entrance position")
	check(first.prepare([parent],[first_patch],{Vector2i(-1,-1):true},Vector2.ZERO),"Complete hidden replacement prepares without touching live scene")
	check(parent.get_surface_override_material(0)==null and shape_node.shape.get_rid()==original_rid and shape_node.transform==original_transform and not first_patch.visible and first_patch.get_node("CaveCollision").collision_layer==0,"Preparation leaves BOTH active rendering and native ground unchanged")
	for frame in range(3):await physics_frame
	check(absf(floor_at(parent,Vector2(-32,-32))-20)<.03,"No premature collider hole while replacement is only prepared")
	check(first.commit(),"All validated resources commit in one main-thread call")
	for frame in range(3):await physics_frame
	check(absf(floor_at(parent,Vector2(-32,-32))-10)<.03 and absf(floor_at(parent,Vector2(32,32))-20)<.03,"Actual native opening reaches new floor while adjacent original surface remains intact")
	check(first_patch.visible and first_patch.get_node("CaveCollision").collision_layer==1 and shape_node.transform==Transform3D.IDENTITY and parent.get_surface_override_material(0)!=null,"Visible cave/parent mask/exact shape use one committed state")
	var second_patch:MeshInstance3D=patch(Vector3.ZERO,12);var second=Transaction.new();check(second.prepare([parent],[second_patch],{Vector2i.ZERO:true},Vector2.ZERO,first),"Next cut prepares from canonical baseline,not from already-clipped ground")
	parent.position.x+=1;check(not second.commit() and first.committed and first_patch.visible and not second_patch.visible,"Stale moved parent rejects commit before ANY mutation of existing active cut");parent.position.x-=1
	check(second.commit() and second.previous==null,"Replacement atomically restores old region and drops historical transaction chain")
	for frame in range(3):await physics_frame
	check(absf(floor_at(parent,Vector2(-32,-32))-20)<.03 and absf(floor_at(parent,Vector2(32,32))-12)<.03,"Old hole closes and new hole/floor activate together without cumulative ground loss")
	check(not first_patch.visible and first_patch.get_node("CaveCollision").collision_layer==0 and second_patch.visible,"Obsolete patch rendering and collision deactivate together")
	second.reset()
	for frame in range(3):await physics_frame
	check(shape_node.shape.get_rid()==original_rid and shape_node.transform==original_transform and parent.get_surface_override_material(0)==null,"Reset restores exact original shape RID/transform/material,not a reconstructed approximation")
	check(absf(floor_at(parent,Vector2(-32,-32))-20)<.03 and absf(floor_at(parent,Vector2(32,32))-20)<.03,"Native zero-cut mode restores both original ground positions")
	parent.queue_free();first_patch.queue_free();second_patch.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable surface transaction source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_transaction.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"production_runtime_enabled":false,"scope":"Main-thread transaction primitive with real original heightfield/nonidentity transform,RID-preserving zero-mode,two successive64m holes/floors,preparation no-mutation and stale-parent rejection. Native physics rays after each state. Not actual ChunkTerrain worker/cut integration,rendered full-biome appearance or sparse live cave streaming."},"  "));print("CAVE_SURFACE_TRANSACTION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
