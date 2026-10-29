extends SceneTree
## Diagnostic: prepare the exact full shader before loading terrain image banks.
## Unlike the older warm-up, this does NOT load terrain.tres or main.tscn first.
func _initialize()->void:call_deferred("warm")
func warm()->void:
	assert(DisplayServer.get_name()!="headless")
	assert(not ResourceLoader.has_cached("res://materials/terrain.tres"))
	assert(not ResourceLoader.has_cached("res://scripts/chunk_terrain.gd"))
	var started:int=Time.get_ticks_usec()
	var hashes:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/biome_extensions/render_terrain_shader_variants.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biological_sampling.gdshaderinc","res://scenes/main.tscn","res://project.godot"]:hashes[path]=FileAccess.get_sha256(path)
	var shader:Shader=load("res://shaders/terrain_biomes.gdshader")
	var candidate_path:String="res://tools/biome_extensions/tissue_target_candidate.gd";hashes[candidate_path]=FileAccess.get_sha256(candidate_path)
	var tissue:String=load(candidate_path).apply_to(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc").replace('#include "res://shaders/biological_sampling.gdshaderinc"',tissue).replace("alien_tissue_sample(","alien_tissue_sample_compact_targets(")
	shader.code=shader.code.replace('#include "res://shaders/biome_extensions.gdshaderinc"',extensions)
	var material:=ShaderMaterial.new();material.shader=shader
	var pixel:=Image.create_empty(1,1,false,Image.FORMAT_RGBA8);pixel.fill(Color(.5,.5,.5,1))
	var layers:Array[Image]=[]
	for i in range(9):layers.append(pixel)
	var tiny_array:=Texture2DArray.new();assert(tiny_array.create_from_images(layers)==OK)
	for bank:String in ["palette_color","palette_normal","cliff_ambient_normals","biological_colors","mountain_colors","mountain_normals","savanna_colors","savanna_normals","jungle_colors","jungle_normals","forest_colors","forest_normals","swamp_colors","swamp_normals","beach_colors","beach_normals"]:material.set_shader_parameter(bank,tiny_array)
	var payload:=Image.create_empty(8,1,false,Image.FORMAT_RGBA8);payload.set_pixel(6,0,Color(.4,.2,.3,.2));payload.set_pixel(7,0,Color(.4,.2,.3,.2))
	material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(payload));material.set_shader_parameter("extension_payload_enabled",true);material.set_shader_parameter("extension_active_mask",192)
	material.set_shader_parameter("extension_normals",PackedFloat32Array([1,1,1,1,1,1,1,1]));material.set_shader_parameter("extension_emission",PackedFloat32Array([0,0,0,0,0,0,0,0]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,0),Vector3(0,0,256),Vector3(256,0,256),Vector3(256,0,0)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(1,0,0,0),Color(1,0,0,0),Color(1,0,0,0),Color(1,0,0,0)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]);arrays[Mesh.ARRAY_TEX_UV2]=arrays[Mesh.ARRAY_TEX_UV]
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var flags:int=0
	for bank in range(4):
		var data:=PackedFloat32Array();data.resize(16);arrays[Mesh.ARRAY_CUSTOM0+bank]=data
		flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][bank]
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,material)
	var stage:=Node3D.new();var node:=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
	var sun:=DirectionalLight3D.new();sun.transform=Transform3D(Vector3(.88294756,.36994863,-.2890356),Vector3(0,.6156615,.7880107),Vector3(.46947157,-.6957722,.5435968),Vector3.ZERO);sun.light_color=Color(1,.94,.82);sun.light_energy=1.15;sun.shadow_enabled=true;sun.directional_shadow_max_distance=500;stage.add_child(sun)
	var environment:=Environment.new();environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.72,.8,.9);environment.ambient_light_energy=.45;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.fog_enabled=true;environment.fog_light_color=Color(.66,.74,.81);environment.fog_density=.000035
	var world:=WorldEnvironment.new();world.environment=environment;stage.add_child(world)
	var camera:=Camera3D.new();camera.position=Vector3(128,100,300);stage.add_child(camera);root.add_child(stage);camera.look_at(Vector3(128,0,128));camera.current=true
	print("LOW_MEMORY_FULL_SHADER_WARM_BEGIN")
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image()!=null)
	var seconds:float=(Time.get_ticks_usec()-started)/1000000.0
	print("LOW_MEMORY_FULL_SHADER_WARM_DRAWN seconds=",seconds)
	root.set_meta("low_memory_shader_warmup",{"seconds":seconds,"source_sha256":hashes,"original_shader":shader,"real_image_banks_loaded_before_warmup":false})
	root.set_meta("prepared_tissue_target_shader",{"shader":shader,"generated_sha256":shader.code.sha256_text(),"seconds":seconds,"source_sha256":hashes})
	stage.queue_free();await process_frame;await process_frame
	set_script(load("res://tools/biome_extensions/render_prepared_tissue_target.gd"));call_deferred("run")
