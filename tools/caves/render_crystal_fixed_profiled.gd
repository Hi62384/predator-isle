extends "res://tools/caves/render_crystal_fixed_scene.gd"
func inspection_name()->String:return "crystal_profiled_fixed_"+target_key
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();result["res://tools/caves/render_crystal_fixed_scene.gd"]=FileAccess.get_sha256("res://tools/caves/render_crystal_fixed_scene.gd");return result
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	# Actual native submission counters,not nominal mesh/LOD metadata. Timings
	# are explicitly nonisolated stationary render samples,never walking FPS.
	var largest:Dictionary={};var near_nodes:int=0;var far_nodes:int=0;var collision_shapes:int=0
	for form:Dictionary in data.placements:
		if form.kind=="crystal" and str(form.id).begins_with(str(data.room.id)+"/") and (largest.is_empty() or form.height>largest.height):largest=form
	for cell:Node in nodes:
		for child:Node in cell.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("CaveBiome_crystal_"):
				near_nodes+=int(not str(child.name).ends_with("_OpaqueFar"));far_nodes+=int(str(child.name).ends_with("_OpaqueFar"))
			if child is StaticBody3D:collision_shapes+=child.get_child_count()
	if not largest.is_empty():camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(largest.bounds.get_center())
	light.position=camera.position+Vector3.UP*.5;light.visible=true;inspection.mesh_lod_threshold=0
	var original:Image=await crystal_picture("profile_near_full_indices");var near:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME);var near_calls:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	inspection.mesh_lod_threshold=10000;var far:Image=await crystal_picture("profile_forced_far_indices");var far_count:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME);var far_calls:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	inspection.mesh_lod_threshold=0;var restored:Image=await crystal_picture("profile_near_exact_return");check(original.get_data()==restored.get_data(),"Actual native index LOD restores exact complete current mineral/host image")
	var measured:bool=RenderingServer.has_method("viewport_set_measure_render_time") and RenderingServer.has_method("viewport_get_measured_render_time_gpu") and RenderingServer.has_method("viewport_get_measured_render_time_cpu");var samples:Array=[]
	if measured:
		RenderingServer.call("viewport_set_measure_render_time",inspection.get_viewport_rid(),true)
		for frame in range(36):
			await process_frame;await RenderingServer.frame_post_draw
			if frame>=6:samples.append({"cpu_ms":RenderingServer.call("viewport_get_measured_render_time_cpu",inspection.get_viewport_rid()),"gpu_ms":RenderingServer.call("viewport_get_measured_render_time_gpu",inspection.get_viewport_rid())})
		RenderingServer.call("viewport_set_measure_render_time",inspection.get_viewport_rid(),false)
	return {"native_near_primitives":near,"forced_far_primitives":far_count,"native_lod_reduces_submitted_primitives":far_count<near,"near_draw_calls":near_calls,"forced_far_draw_calls":far_calls,"lod_image_changes":original.get_data()!=far.get_data(),"lod_exact_return":original.get_data()==restored.get_data(),"native_feature_nodes":near_nodes,"native_far_proxy_nodes":far_nodes,"native_cell_collision_shapes":collision_shapes,"stationary_viewport_measurement_supported":measured,"stationary_viewport_time_samples":samples,"scope":"Actual fixed normal generated mineral scene,complete native submissions and diagnostic index LOD0/10000/0 counterfactual. Stationary renderer CPU/GPU samples with unrelated Godot sessions intentionally left running;not isolated,uninterrupted traversal FPS or frame-budget certification. Original20unique scene inventory locations retained;no probability/theme/size changes."}
