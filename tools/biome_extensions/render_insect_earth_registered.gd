extends "res://tools/biome_extensions/render_insect_earth_candidate.gd"
const PRIVATE_VIEWS="res://tools/biome_extensions/artifacts/revisions/experiment_insect_earth_trial_6eec1813dcd5/sources/tools/biome_extensions/artifacts/render_insect_earth_candidate.json.txt"
func configured_materials(enabled:bool)->int:
	var expected:String="res://shaders/insect_earth.gdshader" if enabled else "res://shaders/biome_structures.gdshader";var count:int=0
	verify(terrain._settings_snapshot.insect_colony.nest_earth_material==enabled,"Actual immutable saved material setting")
	verify(terrain._extension_materials[1].shader.resource_path==expected,"Actual controller selects complete configured shader")
	for node:MeshInstance3D in terrain._active_chunks.values():
		var visible:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if visible==null or visible.mesh==null:continue
		var mesh:ArrayMesh=visible.mesh
		for surface in range(mesh.get_surface_count()):
			var material:ShaderMaterial=mesh.surface_get_material(surface)
			if material.get_shader_parameter("family")!=6:continue
			verify(material.shader.resource_path==expected,"Actual committed per-root configured earth shader")
			verify(is_equal_approx(material.get_shader_parameter("normal_strength"),terrain._settings_snapshot.insect_colony.normal_strength),"Actual configured normal control retained")
			count+=1
	return count
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in [PRIVATE_VIEWS,"res://tools/biome_extensions/render_insect_earth_registered.gd","res://tools/biome_extensions/render_insect_earth_candidate.gd","res://tools/biome_extensions/render_crystal_bulk_candidate.gd","res://tools/biome_extensions/render_ground_union_worker_domains.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var input=JSON.parse_string(FileAccess.get_file_as_string(PRIVATE_VIEWS));assert(input.passed);var views:Array=[]
	for view:Dictionary in input.views:
		if view.phase==0:views.append(view)
	assert(views.size()==6);var focus:Vector3=vector(views[0].focus);var originals:Dictionary={};var original_cuts:Dictionary={};var records:Array=[]
	for phase in range(3):
		var enabled:bool=phase==1;scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain");terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.insect_colony.nest_earth_material=enabled;terrain.extension_preview="insect_colony";terrain.extension_preview_position=Vector2(focus.x,focus.z);terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
		verify(terrain.maximum_lod==6 and terrain.worker_count==4,"Unmodified full hierarchy and actual four-worker controller")
		for view:Dictionary in views:
			terrain.request_teleport(vector(view.camera));assert(await settle());camera.look_at(vector(view.focus));freeze_water_time();terrain.set_debug_view(0);var bindings:int=configured_materials(enabled);verify(bindings>0,"Positive actual committed Insect material bindings")
			var current:Dictionary=cut()
			if phase==0:original_cuts[view.view]=current
			else:verify(current==original_cuts[view.view],"Every actual geometry/terrain/water/features/control/complete collision array exact across saved setting")
			for idle in range(24):await process_frame
			await RenderingServer.frame_post_draw;var picture:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/insect_earth_registered_%d_%s.png"%[phase,view.view];verify(picture.save_png(path)==OK,"Saved complete configured native image");captures[path]=FileAccess.get_sha256(path);var changed:int=0
			if phase==0:originals[view.view]=picture
			else:changed=different(originals[view.view],picture)
			var gpu:Array=[]
			for frame in range(12):
				await process_frame;var cost:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				if cost>0:gpu.append(cost)
			records.append({"phase":phase,"enabled":enabled,"view":view.view,"camera":view.camera,"focus":view.focus,"material_bindings":bindings,"cold_scene_different_bytes":changed,"gpu_median_ms":median(gpu) if not gpu.is_empty() else null});print("REGISTERED_EARTH_NATIVE ",phase," ",view.view)
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable registered earth native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_insect_earth_registered.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"scope":"REGISTERED actual saved Resource false/true/false and untouched configured four-worker/fullLOD6 controller. Eighteen complete native images at all three original geographic poses plus all three separately admitted original close controls. Base and actual per-root shader/normal controls verified. Every full terrain/water/atlas/features/structure/indexed collision byte exact. Cross-cold-scene pixels reported,not claimed exact;private accepted same-scene study separately has six strict original returns. Visible waterTIME0 private duplicates only;unchanged sun/lighting. NON-ISOLATED single-order GPU block medians,not repeated speedup/end-to-end/art/cave certificate."},"  "));quit(0 if failures.is_empty() else 1)
