extends SceneTree
## Private load-order control. No ChunkTerrain/material/image preloads here.
func _initialize()->void:call_deferred("warm")
func warm()->void:
	var path:String="res://shaders/terrain_biomes.gdshader";assert(not ResourceLoader.has_cached(path))
	var shader:=Shader.new();shader.code=FileAccess.get_file_as_string(path);shader.take_over_path(path);root.set_meta("early_full_shader",shader)
	var started:int=Time.get_ticks_usec();print("EARLY_FULL_SHADER_WARM_BEGIN")
	var scene:=Node3D.new();var mesh:=ArrayMesh.new();var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]);arrays[Mesh.ARRAY_TEX_UV2]=arrays[Mesh.ARRAY_TEX_UV]
	var flags:int=0
	for channel in range(4):
		var values:=PackedFloat32Array();values.resize(16);arrays[Mesh.ARRAY_CUSTOM0+channel]=values
		flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][channel]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	var material:=ShaderMaterial.new();material.shader=shader;mesh.surface_set_material(0,material)
	var node:=MeshInstance3D.new();node.mesh=mesh;scene.add_child(node)
	var sun:=DirectionalLight3D.new();sun.rotation=Vector3(-.7,-.7,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=500;scene.add_child(sun)
	var environment:=Environment.new();environment.background_mode=2;environment.sky=Sky.new();environment.sky.sky_material=ProceduralSkyMaterial.new();environment.ambient_light_source=3;environment.fog_enabled=true;environment.fog_density=.000035
	var world:=WorldEnvironment.new();world.environment=environment;scene.add_child(world)
	var camera:=Camera3D.new();camera.position=Vector3(0,3,1);scene.add_child(camera);root.add_child(scene);camera.look_at(Vector3.ZERO);camera.current=true
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw;assert(root.get_texture().get_image()!=null)
	root.set_meta("early_full_shader_seconds",(Time.get_ticks_usec()-started)/1000000.0);print("EARLY_FULL_SHADER_WARM_DRAWN seconds=",root.get_meta("early_full_shader_seconds"))
	scene.queue_free();await process_frame;await process_frame
	assert(ResourceLoader.get_cached_ref(path)==shader)
	set_script(load("res://tools/biome_extensions/render_early_full_shader_warmup.gd"));call_deferred("run")
