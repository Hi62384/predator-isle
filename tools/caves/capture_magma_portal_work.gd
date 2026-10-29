extends "res://tools/caves/check_live_magma_return.gd"
func run()->void:
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_live_magma_return.gd","res://tools/caves/check_live_portal.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scenes/main.tscn","res://project.godot"]:guards[path]=FileAccess.get_sha256(path)
	var b=fixture_builder();var region:Dictionary=fixture_region(b);check(region.valid and region.nodes.size()==17,"Same first normal source region has all17 original core nodes")
	var access:PackedVector3Array=region.edges[0].points;var p:Vector3=access[0];var direction:Vector3=(access[1]-p)*Vector3(1,0,1);direction=direction.normalized();var start:Vector3=p-direction*40;start.y=b._get_height(start.x,start.z)+.95
	var walker:=CharacterBody3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var collision:=CollisionShape3D.new();collision.shape=capsule;walker.add_child(collision);root.add_child(walker);walker.position=start
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain.target=walker;terrain.extension_preview=fixture_name();terrain.extension_preview_position=Vector2(start.x,start.z);terrain.profile_streaming=true
	for name:String in ["jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"]:terrain.set("start_in_"+name,false)
	terrain.cave_settings=fixture_configuration();prepare_live_terrain(terrain,b);root.add_child(scene);scene.get_node("Interface").hide();terrain._refresh_visible_chunks();camera.position=start+Vector3(0,10,18);camera.look_at(p)
	var began:int=Time.get_ticks_usec();var captured:Dictionary={};var observations:Array=[];var last_print:int=-1
	while Time.get_ticks_usec()-began<60000000:
		await process_frame;OS.delay_usec(1000);var stream=terrain._cave_streamer;var elapsed:int=(Time.get_ticks_usec()-began)/1000000
		if elapsed/10!=last_print:
			last_print=elapsed/10;var jobs:Array=[]
			for job:Dictionary in stream._jobs.values():jobs.append({"kind":job.kind,"key":str(job.get("key","")),"part":job.get("part",-1)})
			observations.append({"elapsed":elapsed,"jobs":jobs,"cells":stream._cells.size(),"status":stream.surface_status});print("MAGMA_PORTAL_TRACE ",observations[-1])
		if captured.is_empty() and stream._surface_batch!=null:
			var batch=stream._surface_batch;var data:Dictionary={"bundle":stream._bundle,"columns":batch.request.columns,"parents":batch.request.snapshot.records,"owned_columns":batch.groups[0],"settings":b.settings,"seed":17,"configuration":fixture_configuration()}
			# Resources are saved separately as native text;replay input contains
			# immutable numeric records only,never parent nodes/materials/jobs.
			data.erase("settings");data.erase("configuration");var path:String="res://tools/biome_extensions/artifacts/magma_first_portal_work.bin";var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(data,false);file.close();guards[path]=FileAccess.get_sha256(path);captured={"path":path,"bytes":FileAccess.get_file_as_bytes(path).size(),"columns":data.columns.size(),"owned_columns":data.owned_columns.size(),"parents":data.parents.size(),"parts":batch.groups.size()};print("MAGMA_PORTAL_CAPTURE ",captured)
	check(not captured.is_empty(),"Captured exact original stalled production batch numeric workload without changing location/jobs/geometry")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable capture source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_portal_capture.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"captured":captured,"observations":observations,"scope":"Diagnostic60s stationary preparation trace and immutable numeric snapshot of same original failed first normal Magma entrance. Captures main-thread batch metadata and immutable bundle/parent arrays only;does not inspect mutating worker fields. Not a passing180s portal/preload/traversal/performance gate."},"  "));print("MAGMA_PORTAL_CAPTURE_COMPLETE ",checks," failures=",failures);scene.queue_free();walker.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
