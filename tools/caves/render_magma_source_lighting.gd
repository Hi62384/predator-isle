extends "res://tools/caves/render_magma_intrusive_world.gd"
func report_basename()->String:return "render_cave_magma_source_lighting"
func capture_prefix()->String:return "magma_source_lighting"
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,lamp:OmniLight3D)->Dictionary:
	var stream=Streamer.new();stream.configuration=Config.new();stream.configuration.enabled=true;stream.configuration.biome_regions=FrozenFixture.registry(stream.configuration.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));stream._bundle=data.bundle;root.add_child(stream)
	for index in range(data.cells.size()):stream._cells[data.cells[index].key]=nodes[index]
	stream.configure_biome_runtime();check(stream._biome_runtime_controllers.size()==1,"Exactly one main-thread molten-light controller from generic provider hook")
	var controller=stream._biome_runtime_controllers[0];var point:=Vector3(data.pool.center.x,data.pool.water_y+2,data.pool.center.z);controller.update(stream,point);var source_light:OmniLight3D=controller.light;check(is_instance_valid(source_light) and source_light.visible and controller.source_id==str(data.pool.id) and source_light.shadow_enabled and source_light.omni_range<=48,"One bounded shadowed light bound to exact actual uploaded molten source")
	var lamp_before:bool=lamp.visible;lamp.visible=false;var on:Image=await capture("natural_source_light_on");source_light.visible=false;var off:Image=await capture("natural_source_light_off");source_light.visible=true;var returned:Image=await capture("natural_source_light_return");check(on.get_data()!=off.get_data() and on.get_data()==returned.get_data(),"Source lighting visibly illuminates actual nearby cave rock and returns pixel-exact with no test lamp")
	var bound_key:Vector3i=controller.source_key;var saved_node=stream._cells[bound_key];stream._cells.erase(bound_key);controller.update(stream,point);check(not source_light.visible,"Missing uploaded molten cell immediately disables source light despite cached proximity")
	stream._cells[bound_key]=saved_node;controller.configure(load("res://config/caves/biomes/magma_cave_definition.tres").material_configuration);controller.update(stream,point);check(source_light.visible and stream.get_child_count()==1,"Uploaded source restored using same single light node")
	controller.update(stream,point+Vector3(500,0,0));check(not source_light.visible and stream.get_child_count()==1,"Far-away sources do not light cold cave volume or allocate more lights")
	var original_bundle:Dictionary=stream._bundle;var wrong:Dictionary=data.pool.duplicate();wrong.id="never_uploaded_basin";stream._bundle={"regions":[{"pools":[wrong]}]};controller.configure(load("res://config/caves/biomes/magma_cave_definition.tres").material_configuration);controller.update(stream,point);check(not source_light.visible,"A different unuploaded basin cannot borrow another pool's uploaded mesh/cell")
	stream._bundle=original_bundle;controller.configure(load("res://config/caves/biomes/magma_cave_definition.tres").material_configuration);controller.update(stream,point);check(source_light.visible and controller.source_id==str(data.pool.id),"Exact real source restoration after negative case")
	for mode:String in ["root_off","registry_off","disabled","zero_spawn","lighting_off","energy_zero"]:
		var probe=Streamer.new();probe.configuration=stream.configuration.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		if mode=="registry_off":probe.configuration.biome_regions.enabled=false
		if mode=="root_off":probe.configuration.enabled=false
		for definition:Resource in probe.configuration.biome_regions.definitions:
			if str(definition.biome_id)!="magma":continue
			match mode:
				"disabled":definition.enabled=false
				"zero_spawn":definition.spawn_chance_percent=0.0
				"lighting_off":definition.material_configuration.lava_lighting=false
				"energy_zero":definition.material_configuration.lava_light_energy=0.0
		probe.configure_biome_runtime();check(probe._biome_runtime_controllers.is_empty() and probe.get_child_count()==0,"Independent "+mode+" creates no source light/controller");probe.free()
	var result:Dictionary={"source_pool":controller.source_id,"source_kind":source_light.get_meta("source_kind"),"maximum_source_lights":stream.get_child_count(),"energy":source_light.light_energy,"range_m":source_light.omni_range,"natural_pixels_differ":on.get_data()!=off.get_data(),"test_lamp_disabled_for_source_comparison":true}
	controller.release();stream._biome_runtime_controllers.clear();stream._cells.clear();stream._bundle={};stream.queue_free();await process_frame;lamp.visible=lamp_before;return result
func scope_description()->String:return "Exact first normal source-backed molten pool17/(-73,138),normal biome22percent/source4percent/molten14percent controls. Actual production native shared cave geometry/collision/materials and generic main-thread source-light controller;ONE shadowed bounded light,exact uploaded basin-ID check,off/far/unuploaded/disabled/zero controls and no-lamp natural lighting on/off/exactreturn. Same original passage return with candidate-free production collision. Test-only lamp used only for separate material/geometry captures;lava clock frozen for deterministic pixels. No full live/FPS/reference-art/all-user completion claim."
