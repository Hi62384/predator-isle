extends SceneTree
## Actual committed production collision at non-flat Badlands landmarks.
var checks:int=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func settle(terrain)->void:
	var started:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-started<180000,"Landmark collision preload timeout")
func committed_vertex(terrain,p:Vector3,cache:Dictionary)->Dictionary:
	for key:Vector3i in terrain._active_chunks:
		if not terrain._partition.bounds(key).has_point(Vector2(p.x,p.z)):continue
		assert(key.z<=1,"Landmark must have committed near collision")
		var node:MeshInstance3D=terrain._active_chunks[key];var resolution:int=node.get_meta("resolution")
		var step:float=terrain.chunk_size*float(1<<key.z)/resolution
		var x:int=clampi(roundi((p.x-node.global_position.x)/step),1,resolution-1)
		var z:int=clampi(roundi((p.z-node.global_position.z)/step),1,resolution-1)
		if not cache.has(key):cache[key]=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var vertices:PackedVector3Array=cache[key]
		return {"position":node.global_position+vertices[z*(resolution+1)+x],"step_m":step,"tile":key}
	assert(false,"No committed mesh at landmark sample");return {}
func run()->void:
	var sources:Dictionary={}
	for path:String in ["res://scripts/badlands_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_collision.gd","res://data/badlands_previews.json","res://tools/badlands/check_native_landmarks.gd"]:sources[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	var target:=Node3D.new();root.add_child(target)
	var scene=load("res://scenes/main.tscn").instantiate();scene.get_node("FreeCamera").set_script(null)
	var terrain=scene.get_node("Terrain");terrain.badlands_preview=true;terrain.badlands_preview_feature="painted_hills";terrain.target=target
	root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
	var records:Array=[]
	for name:String in ["painted_hills","dense_gullies","knife_edge_ridges","hoodoo_cluster","rare_pool"]:
		var site:Dictionary=manifest.features[name];var p:=Vector3(roundf(site.x/2)*2,0,roundf(site.z/2)*2);p.y=terrain.get_height_at(p)+8
		terrain.request_teleport(p);await settle(terrain);await physics_frame;await physics_frame
		var maximum_error:float=0;var maximum_mesh_error:float=0;var hits:int=0;var cache:Dictionary={};var steps:Dictionary={}
		for z in range(-2,3):
			for x in range(-2,3):
				var sample:Dictionary=committed_vertex(terrain,p+Vector3(x*8,0,z*8),cache);var q:Vector3=sample.position
				steps[str(sample.step_m)]=true
				var expected:float=terrain.get_height_at(q);var mesh_error:float=absf(q.y-expected);maximum_mesh_error=maxf(maximum_mesh_error,mesh_error);checks+=1
				if mesh_error>.02:failures.append(name+" canonical/committed-mesh vertex error "+str(mesh_error)+" at "+str(q))
				var query:=PhysicsRayQueryParameters3D.create(Vector3(q.x,expected+2000,q.z),Vector3(q.x,expected-2000,q.z),1)
				var hit:Dictionary=terrain.get_world_3d().direct_space_state.intersect_ray(query);checks+=1
				if hit.is_empty():failures.append(name+" missing committed ground at "+str(q));continue
				hits+=1;var error:float=absf(hit.position.y-q.y);maximum_error=maxf(maximum_error,error)
				if error>.02:failures.append(name+" committed-mesh/physics vertex error "+str(error)+" at "+str(q))
		records.append({"feature":name,"hits":hits,"grid_steps_m":steps.keys(),"maximum_canonical_mesh_error_m":maximum_mesh_error,"maximum_mesh_physics_error_m":maximum_error,"committed_revision":terrain.committed_revision,"partition_revision":terrain.partition_revision})
	for path:String in sources:assert(FileAccess.get_sha256(path)==sources[path],"Source changed during landmark collision check")
	var report:Dictionary={"checks":checks,"rays":125,"failures":failures,"passed":failures.is_empty(),"records":records,"source_sha256":sources,"scope":"125 native Jolt rays at actual committed production-grid vertices, five non-flat/water landmarks. Canonical-to-mesh and mesh-to-physics height checks, actual workers/collision. Not a capsule route, seam, arbitrary off-grid or interior cave test."}
	FileAccess.open("res://tools/badlands/artifacts/check_native_landmarks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_NATIVE_LANDMARKS ",checks," checks / 125 rays; failures=",failures)
	scene.queue_free();target.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
