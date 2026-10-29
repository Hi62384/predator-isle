extends "res://tools/caves/render_crystal_fixed_scene.gd"
func inspection_name()->String:return "crystal_reflection_candidate_"+target_key
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();result["res://tools/caves/render_crystal_fixed_scene.gd"]=FileAccess.get_sha256("res://tools/caves/render_crystal_fixed_scene.gd");return result
func inspection_material_checks(data:Dictionary,_nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var largest:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal" and str(form.id).begins_with(str(data.room.id)+"/") and (largest.is_empty() or form.height>largest.height):largest=form
	if not largest.is_empty():camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(largest.bounds.get_center())
	light.position=camera.position+Vector3.UP*.5;light.visible=true
	var original:Image=await crystal_picture("original_sky_only_reflections")
	var probe:=ReflectionProbe.new();probe.name="PrivateSingleInteriorProbe";probe.position=data.room.point+Vector3.UP*3;probe.size=Vector3(64,64,64);probe.max_distance=80;probe.interior=true;probe.box_projection=true;probe.update_mode=ReflectionProbe.UPDATE_ONCE;probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;probe.enable_shadows=true;root.add_child(probe)
	for frame in range(30):await process_frame;await RenderingServer.frame_post_draw
	var reflected:Image=await crystal_picture("single_actual_cave_reflection_probe");var changed:int=0;var before:PackedByteArray=original.get_data();var after:PackedByteArray=reflected.get_data()
	for index in range(0,mini(before.size(),after.size()),4):changed+=int(before[index]!=after[index] or before[index+1]!=after[index+1] or before[index+2]!=after[index+2])
	var samples:Array=[];var measured:bool=RenderingServer.has_method("viewport_set_measure_render_time") and RenderingServer.has_method("viewport_get_measured_render_time_gpu")
	if measured:
		RenderingServer.call("viewport_set_measure_render_time",inspection.get_viewport_rid(),true)
		for frame in range(36):
			await process_frame;await RenderingServer.frame_post_draw
			if frame>=6:samples.append({"cpu_ms":RenderingServer.call("viewport_get_measured_render_time_cpu",inspection.get_viewport_rid()),"gpu_ms":RenderingServer.call("viewport_get_measured_render_time_gpu",inspection.get_viewport_rid())})
		RenderingServer.call("viewport_set_measure_render_time",inspection.get_viewport_rid(),false)
	probe.queue_free()
	for frame in range(12):await process_frame;await RenderingServer.frame_post_draw
	var restored:Image=await crystal_picture("probe_removed_exact_original_return");check(changed>0,"Single actual interior reflection capture has positive visible effect without changing mineral shader/geometry/light intensity");check(original.get_data()==restored.get_data(),"Removing only private probe returns exact original native image")
	return {"private_reflection_probes":1,"probe_update":"once","probe_box_metres":64,"probe_max_distance_metres":80,"probe_interior":true,"probe_intensity":1.0,"changed_native_pixels":changed,"exact_original_return":original.get_data()==restored.get_data(),"stationary_renderer_time_samples":samples,"scope":"PRIVATE feasibility only. One standard Godot interior box-projected UPDATE_ONCE probe captures the actual existing cave/explicit test-only lamp. Zero new light sources,intensity boosts,per-crystal probes,textures,geometry/collision edits or normal environment changes. Other Godot sessions remain running;not production adoption or isolated/whole-world FPS/reference-art completion."}
