extends "res://tools/biome_extensions/render_all.gd"
const Fixture=preload("res://tools/tropical/volcanic_transition_fixture.gd")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	hashes=Fixture.sources()
	for path:String in ["res://tools/tropical/render_volcanic_transition.gd","res://tools/biome_extensions/render_all.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var b=Fixture.builder();var p:Vector2=Fixture.locate(b);assert(p.is_finite(),"Actual mixed-owner site required")
	b._biome_weights(p.x,p.y);var owner_weights:=Vector2(b._tropical_weight,b._extra_weights[2])
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	camera.position=Vector3(p.x,b._get_height(p.x,p.y)+250,p.y)
	terrain=scene.get_node("Terrain");terrain.settings=b.settings;terrain.target=camera
	for key:String in ["start_in_beach","start_in_coast","start_in_mountain","start_in_swamp","start_in_savanna","start_in_forest","start_in_jungle","start_in_tropical","start_in_badlands"]:terrain.set(key,false)
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
	await capture("tropical_volcanic","medium",focus,Vector3(-500,220,-700))
	await capture("tropical_volcanic","aerial",focus,Vector3(-2400,1800,-3200))
	await capture("tropical_volcanic","normals",focus,Vector3(-60,20,-80),8)
	await capture("tropical_volcanic","owners",focus,Vector3(-500,220,-700),150)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during transition review")
	for record:Dictionary in records:assert(record.committed,"Only committed terrain is evidence")
	FileAccess.open("res://tools/tropical/artifacts/render_volcanic_transition.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"captures":records,"source_sha256":hashes,"owner_weights_at_focus":owner_weights,"focus":p,"maximum_lod":terrain.maximum_lod,"draw_distance":camera.far,"scope":"Four actual production-streamed mixed-owner views. Saved coverage/presets unchanged; not all-world artistic or physics certification."},"  "))
	print("TROPICAL_VOLCANIC_RENDER ",records.size()," committed captures");scene.queue_free();await process_frame;quit()
