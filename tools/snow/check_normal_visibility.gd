extends SceneTree
var terrain:Node
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func wait_for_terrain()->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<90000,"Streaming timeout")
func frame(debug:int)->Image:
	terrain.set_debug_view(debug)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless","Requires actual rendering")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null)
	terrain=scene.get_node("Terrain");terrain.snow_preview=true;terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide()
	await wait_for_terrain()
	var specialized_surfaces:int=0
	for key:Vector3i in terrain._active_chunks:
		if terrain._active_chunks[key].mesh.surface_get_material(0)==terrain._snow_lod_materials.get(key.z):specialized_surfaces+=1
	assert(specialized_surfaces>0,"Pure Snow shader path was not exercised")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/snow_previews.json"));var records:Array=[];var failures:Array=[]
	var marker=preload("res://scripts/player_scale_marker.gd").new();scene.add_child(marker);marker.hide()
	for name:String in ["huge_snowfield","arctic_tundra","exposed_peaks","valley_glacier"]:
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=terrain.get_height_at(focus)
		if name=="exposed_peaks":
			# An exposed-rock normal test needs an illuminated rock face, not a
			# fully shadowed back face selected by an old preview's summit point.
			# Search the actual generated terrain; retain the scene's own Sun.
			var light:Vector3=scene.get_node("Sun").global_basis.z.normalized()
			var best:float=-INF;var origin:Vector3=focus
			for z in range(-12,13):
				for x in range(-12,13):
					var p:Vector3=origin+Vector3(x*32,0,z*32);p.y=terrain.get_height_at(p)
					var hx:float=terrain.get_height_at(p+Vector3(8,0,0))-terrain.get_height_at(p-Vector3(8,0,0))
					var hz:float=terrain.get_height_at(p+Vector3(0,0,8))-terrain.get_height_at(p-Vector3(0,0,8))
					var n:=Vector3(-hx,16,-hz).normalized()
					terrain._sampler._snow.sample(p.x,p.z)
					if n.y>.8 or terrain._sampler._snow.c.x<.3:continue
					var score:float=n.dot(light)-float(x*x+z*z)*.0002
					if score>best:best=score;focus=p
		var point:Vector3=focus+Vector3(-4,2,-6);point.y=maxf(point.y,terrain.get_height_at(point)+2.0)
		terrain.request_teleport(point);await wait_for_terrain();camera.near=.1;camera.look_at(focus)
		marker.place(camera,terrain)
		var on:Image=await frame(0)
		for key:Vector3i in terrain._active_chunks:terrain._active_chunks[key].material_override=terrain._lod_materials[key.z]
		var generic:Image=await frame(0)
		for node:MeshInstance3D in terrain._active_chunks.values():node.material_override=null
		var off:Image=await frame(7)
		for material:ShaderMaterial in terrain._material_variants():material.set_shader_parameter("snow_master_strength",0.0)
		var master_off:Image=await frame(0)
		for material:ShaderMaterial in terrain._material_variants():material.set_shader_parameter("snow_master_strength",1.0)
		var mask:Image=await frame(51)
		on.save_png("res://tools/snow/artifacts/normal_"+name+"_on.png");off.save_png("res://tools/snow/artifacts/normal_"+name+"_off.png")
		var sum:float=0;var changed:int=0;var count:int=0;var master_error:float=0;var specialization_error:float=0
		for y in range(180,650,3):
			for x in range(120,1160,3):
				var m:Color=mask.get_pixel(x,y)
				# Snow/ice blends legitimately have no channel above .8. Exclude
				# sky/marker, not the mixed material pixels this test must measure.
				if maxf(m.r,maxf(m.g,m.b))<.35 or minf(m.r,minf(m.g,m.b))>.1:continue
				var a:Color=on.get_pixel(x,y);var b:Color=off.get_pixel(x,y)
				var g:Color=generic.get_pixel(x,y);specialization_error=maxf(specialization_error,maxf(absf(g.r-a.r),maxf(absf(g.g-a.g),absf(g.b-a.b))))
				var c:Color=master_off.get_pixel(x,y);master_error=maxf(master_error,maxf(absf(c.r-b.r),maxf(absf(c.g-b.g),absf(c.b-b.b))))
				var delta:float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0;sum+=delta;count+=1
				if delta>.01:changed+=1
		var pass_gate:bool=count>100 and sum/maxi(count,1)>.001 and float(changed)/maxi(count,1)>.01
		pass_gate=pass_gate and master_error<.008 and specialization_error<.012
		if not pass_gate:failures.append(name)
		records.append({"feature":name,"mean_rgb_difference":sum/maxi(count,1),"changed_fraction":float(changed)/maxi(count,1),"master_off_error":master_error,"specialization_error":specialization_error,"pixels_tested":count,"visible_difference_gate":pass_gate,"camera":str(point),"scale_marker_metres":1.8})
	var result:Dictionary={"records":records,"failures":failures,"actual_render":true,"specialized_surfaces":specialized_surfaces,"note":"Normal-off retains identical Snow albedo sampling; generic/specialized renders are compared on terrain pixels; screenshots require visual inspection as well."}
	var file:=FileAccess.open("res://tools/snow/artifacts/normal_visibility.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SNOW_NORMAL_VISIBILITY ",JSON.stringify(result));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
