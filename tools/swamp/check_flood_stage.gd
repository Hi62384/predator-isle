extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func settle()->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<120000)
func capture(stage:float)->Image:
	terrain.set_swamp_flood_stage(stage)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null)
	terrain=scene.get_node("Terrain");terrain.swamp_preview=true;terrain.swamp_preview_feature="muddy_shore";terrain.target=camera
	root.add_child(scene);scene.get_node("Interface").hide();await settle()
	terrain._swamp_water_material.set_shader_parameter("swamp_ripple",0)
	if terrain._water!=null:terrain._water.mesh.material.set_shader_parameter("wave_speed",0)
	var saved:Array=[];var meshes:Array=[];var revision:int=terrain.committed_revision
	for node:MeshInstance3D in terrain._active_chunks.values():meshes.append(node.mesh.get_instance_id())
	for i in range(100):saved.append(terrain.get_height_at(Vector3(i*37,0,i*53)))
	var low:Image=await capture(0);var high:Image=await capture(1)
	var change:float=0;var count:int=0
	for z in range(250,700,4):
		for x in range(20,1260,4):
			var a:Color=low.get_pixel(x,z);var b:Color=high.get_pixel(x,z);change+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3;count+=1
	change/=count;assert(change>.001,"Flood stage must visibly change shallow margins")
	assert(terrain.committed_revision==revision,"Flood stage must not rebuild the terrain")
	var n:int=0
	for node:MeshInstance3D in terrain._active_chunks.values():assert(meshes[n]==node.mesh.get_instance_id());n+=1
	for i in range(100):assert(saved[i]==terrain.get_height_at(Vector3(i*37,0,i*53)))
	low.save_png("res://tools/swamp/artifacts/flood_low.png");high.save_png("res://tools/swamp/artifacts/flood_high.png")
	FileAccess.open("res://tools/swamp/artifacts/flood_stage.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"mean_rgb_change":change,"unchanged_meshes":meshes.size(),"unchanged_height_queries":100,"same_partition":true},"\t"))
	print("SWAMP_FLOOD_STAGE_PASS ",change," meshes=",meshes.size());scene.queue_free();await process_frame;quit()
