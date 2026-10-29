extends "res://tools/caves/render_magma_world.gd"
var target_key:String="profile_collapsed_lava_tube"
var selection:Dictionary={}
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("target="):target_key=arg.trim_prefix("target=")
	assert(target_key.is_valid_identifier());DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	await super.run()
func index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_magma_scenic_index.json"
func selected_case(catalogue:Dictionary)->Dictionary:
	selection=catalogue.first.get(target_key,{})
	if selection.is_empty():return {}
	return {"ordinal":selection.ordinal,"host":selection.host,"seed":int(selection.seed),"site":selection.site,"rooms":[{"room":{"id":selection.room_id}}]}
func report_basename()->String:return "render_cave_magma_scene_"+target_key
func capture_prefix()->String:return "magma_scene_"+target_key.sha256_text().left(8)
func world_guards()->Dictionary:return {"res://tools/caves/render_magma_scenic_target.gd":FileAccess.get_sha256("res://tools/caves/render_magma_scenic_target.gd")}
func local_route_limit()->float:return 256.0 if target_key.begins_with("tube_") else 60.0
func chosen_route_edge(region:Dictionary,room_id:String)->Dictionary:
	if not target_key.begins_with("tube_"):return super.chosen_route_edge(region,room_id)
	for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
		if str(edge.from)==room_id and str(edge.to)==str(selection.selection.to) and str(edge.get("magma_tube_profile",""))==str(selection.selection.profile):return edge
	return {}
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	if target_key.begins_with("tube_"):check(data.edge.get("magma_tube_profile","")==selection.selection.profile,"Actual whole selected tube profile is the walked edge,not another incident passage")
	var saved_camera:Transform3D=camera.transform;var saved_light:Transform3D=light.transform;var selected_form:Dictionary={};var target:Vector3=data.room.point+Vector3(0,data.room.chamber_height*.3,data.room.chamber_radius*.65)
	if target_key.begins_with("formation_"):
		for form:Dictionary in data.placements:
			if str(form.id)==str(selection.selection.placement_id):selected_form=form;break
		check(not selected_form.is_empty(),"Exact predeclared normal measured formation survives full3x3 neighbouring volume")
		if not selected_form.is_empty():
			var axis:Vector3=selected_form.get("axis",Vector3.UP);target=selected_form.root+axis*selected_form.height*.5
			if axis.y<-.8:camera.position=selected_form.root+Vector3.DOWN*5+Vector3(1,0,1)
			elif absf(axis.y)<.5:camera.position=target+axis*5+Vector3.UP
			else:
				var direction:Vector3=((data.room.point-selected_form.root)*Vector3(1,0,1)).normalized();camera.position=selected_form.root+direction*maxf(5,selected_form.width*3)+Vector3.UP*minf(3,selected_form.height*.5)
	else:camera.position=data.room.point+Vector3.UP*1.8
	camera.look_at(target);light.position=camera.position+Vector3.UP*.5;var old_threshold:float=viewport.mesh_lod_threshold;viewport.mesh_lod_threshold=0
	var near:Image=await capture("selected_ground_view_full_indices");var near_count:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME);var near_calls:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	viewport.mesh_lod_threshold=10000;var far:Image=await capture("selected_forced_far_indices");var far_count:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME);viewport.mesh_lod_threshold=0;var returned:Image=await capture("selected_near_exact_return");check(near.get_data()==returned.get_data(),"Actual selected normal scene restores exact complete image after diagnostic index LOD")
	var collider_name:String="";var collider_hit:bool=false
	if not selected_form.is_empty() and selected_form.collider:
		var axis:Vector3=selected_form.get("axis",Vector3.UP);var hit:Dictionary=nodes[0].get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(selected_form.root+axis*(selected_form.height+.75),selected_form.root-axis*.5,1))
		if not hit.is_empty():
			var body:CollisionObject3D=hit.collider;var owner_id:int=body.shape_find_owner(hit.shape);var shape:Node=body.shape_owner_get_owner(owner_id);collider_name=str(shape.name);collider_hit=collider_name.begins_with("BiomeCollision_magma_cooled_volcanic")
		check(collider_hit,"Actual selected major volcanic form has matching visible-geometry native collider")
	var supported:bool=RenderingServer.has_method("viewport_set_measure_render_time");var samples:Array=[]
	if supported:
		RenderingServer.call("viewport_set_measure_render_time",viewport.get_viewport_rid(),true)
		for frame in range(36):
			await process_frame;await RenderingServer.frame_post_draw
			if frame>=6:samples.append({"cpu_ms":RenderingServer.call("viewport_get_measured_render_time_cpu",viewport.get_viewport_rid()),"gpu_ms":RenderingServer.call("viewport_get_measured_render_time_gpu",viewport.get_viewport_rid())})
		RenderingServer.call("viewport_set_measure_render_time",viewport.get_viewport_rid(),false)
	viewport.mesh_lod_threshold=old_threshold;camera.transform=saved_camera;light.transform=saved_light
	return {"target_key":target_key,"selection":selection,"exact_selected_form":selected_form,"native_form_collision_hit":collider_hit,"native_shape_name":collider_name,"near_submitted_primitives":near_count,"forced_far_submitted_primitives":far_count,"near_draw_calls":near_calls,"native_lod_reduces_submissions":far_count<near_count,"lod_exact_image_return":near.get_data()==returned.get_data(),"lod_image_changes":near.get_data()!=far.get_data(),"stationary_measurement_supported":supported,"stationary_renderer_samples":samples,"scope":"Actual first normal target from full720case catalogue;native3x3 scene and exact selected form/collider,full/far/full index submission and30stationary viewport samples. Unrelated Godot sessions remain running;owned fixtureVSync disabled/max120/enginefixed60Hz is accelerated diagnostic motion,not isolated timing,uninterrupted traversal FPS or reference-art acceptance."}
func scope_description()->String:return "Exact FIRST normal "+target_key+" from complete720case catalogue,including all original144cases and negatives. Original normal probabilities,host,seed,site,room and actual selected formation identity retained. Full3x3 production field/material/features/collisions/frontiers,whole scene geometry-off/exactreturn,diagnostic index LOD/exactreturn,stationary native renderer samples and original ordinary passage two-way prefix. Owned diagnosticVSync disabled/max120/fixed60Hz acceleration,test-only lamp. No probability override;not full live route,isolated/uninterrupted FPS or reference-art approval."
