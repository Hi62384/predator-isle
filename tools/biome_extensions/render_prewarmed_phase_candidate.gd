extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
## Compile/draw the unchanged full shader before large terrain jobs allocate.
var warm_material:ShaderMaterial
func output_basename()->String:return "render_prewarmed_phase_candidate"
func prepare_shader()->void:
	hashes["res://tools/biome_extensions/render_prewarmed_phase_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_prewarmed_phase_candidate.gd")
	var started:int=Time.get_ticks_usec();print("PHASE_PREWARM_BEGIN")
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=73921;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.alien_infected_coverage=100;b.settings.rocky_coast_enabled=false;b.settings.beaches_enabled=false;b._configure_noise();b.chunk_size=256
	var arrays:Array=b.build(Vector2i(-54,-360),2);var mesh:=ArrayMesh.new()
	var flags:int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT if arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*4 else Mesh.ARRAY_CUSTOM_RGB_FLOAT)<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for i in range(1,4):
		if arrays[Mesh.ARRAY_CUSTOM0+i]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << [Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][i-1]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	warm_material=load("res://materials/terrain.tres").duplicate()
	for bank:String in ["mountain","savanna","jungle"]:
		warm_material.set_shader_parameter(bank+"_colors",load("res://materials/"+bank+"_colors.tres"));warm_material.set_shader_parameter(bank+"_normals",load("res://materials/"+bank+"_normals.tres"))
	warm_material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v2.tres"))
	warm_material.set_shader_parameter("extension_normals",PackedFloat32Array([1,1,1,1,1,1,1,1]));warm_material.set_shader_parameter("extension_emission",PackedFloat32Array([0,0,0,0,0,0,0,0]))
	if not b.built_extension_data.is_empty():
		var width:int=b.built_extension_data.size()/(b.built_extension_rows*4)
		warm_material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(Image.create_from_data(width,b.built_extension_rows,false,Image.FORMAT_RGBA8,b.built_extension_data)))
		warm_material.set_shader_parameter("extension_payload_enabled",true);warm_material.set_shader_parameter("extension_active_mask",b.built_extension_mask)
	mesh.surface_set_material(0,warm_material)
	var warm_scene:=Node3D.new();var node:=MeshInstance3D.new();node.mesh=mesh;warm_scene.add_child(node)
	var main=load("res://scenes/main.tscn").instantiate();warm_scene.add_child(main.get_node("Sun").duplicate());warm_scene.add_child(main.get_node("WorldEnvironment").duplicate());main.free()
	var center:Vector3=arrays[Mesh.ARRAY_VERTEX][4];var warm_camera:=Camera3D.new();warm_camera.position=center+Vector3(0,300,1);warm_scene.add_child(warm_camera);root.add_child(warm_scene);warm_camera.look_at(center);warm_camera.current=true
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw;assert(root.get_texture().get_image()!=null)
	print("PHASE_PREWARM_DRAWN seconds=",(Time.get_ticks_usec()-started)/1000000.0)
	warm_scene.queue_free();await process_frame;await process_frame
