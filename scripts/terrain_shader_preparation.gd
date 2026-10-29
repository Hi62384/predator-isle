extends RefCounted
## Prepare the configured program before the large photographed image banks
## are loaded. The normal terrain selects this exact cached Shader instance.
const Variants=preload("res://scripts/terrain_shader_variants.gd")
static func prepare(tree:SceneTree,settings:Resource)->Shader:
	var shader:Shader=Variants.select(load("res://shaders/terrain_biomes.gdshader"),settings)
	if DisplayServer.get_name()=="headless":return shader
	var start:int=Time.get_ticks_usec();var material:=ShaderMaterial.new();material.shader=shader
	var pixel:=Image.create_empty(1,1,false,Image.FORMAT_RGBA8);pixel.fill(Color(.5,.5,.5,1));var layers:Array[Image]=[]
	for index in range(9):layers.append(pixel)
	var bank:=Texture2DArray.new();assert(bank.create_from_images(layers)==OK)
	for name:String in ["palette_color","palette_normal","cliff_ambient_normals","biological_colors","mountain_colors","mountain_normals","savanna_colors","savanna_normals","jungle_colors","jungle_normals","forest_colors","forest_normals","swamp_colors","swamp_normals","beach_colors","beach_normals"]:material.set_shader_parameter(name,bank)
	var payload:=Image.create_empty(8,1,false,Image.FORMAT_RGBA8)
	for index in range(8):payload.set_pixel(index,0,Color(.125,.04,.06,.03))
	material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(payload));material.set_shader_parameter("extension_payload_enabled",true);material.set_shader_parameter("extension_active_mask",Variants.configured_mask(settings)>>8)
	material.set_shader_parameter("extension_normals",PackedFloat32Array([1,1,1,1,1,1,1,1]));material.set_shader_parameter("extension_emission",PackedFloat32Array([0,0,0,0,0,0,0,0]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3(0,0,256),Vector3(256,0,256),Vector3(256,0,0)]);arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(1,0,0,0),Color(1,0,0,0),Color(1,0,0,0),Color(1,0,0,0)]);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]);arrays[Mesh.ARRAY_TEX_UV2]=arrays[Mesh.ARRAY_TEX_UV];arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var flags:int=0
	for index in range(4):
		var data:=PackedFloat32Array();data.resize(16);arrays[Mesh.ARRAY_CUSTOM0+index]=data;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][index]
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,material)
	var viewport:=SubViewport.new();viewport.size=Vector2i(32,32);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;tree.root.add_child(viewport)
	var node:=MeshInstance3D.new();node.mesh=mesh;viewport.add_child(node)
	var sun:=DirectionalLight3D.new();sun.transform=Transform3D(Vector3(.88294756,.36994863,-.2890356),Vector3(0,.6156615,.7880107),Vector3(.46947157,-.6957722,.5435968),Vector3.ZERO);sun.light_color=Color(1,.94,.82);sun.light_energy=1.15;sun.shadow_enabled=true;sun.directional_shadow_max_distance=500;viewport.add_child(sun)
	var environment:=Environment.new();environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.72,.8,.9);environment.ambient_light_energy=.45;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.fog_enabled=true;environment.fog_light_color=Color(.66,.74,.81);environment.fog_density=.000035
	var world:=WorldEnvironment.new();world.environment=environment;viewport.add_child(world);var camera:=Camera3D.new();camera.position=Vector3(128,100,300);viewport.add_child(camera);camera.look_at(Vector3(128,0,128));camera.current=true
	for frame in range(8):await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.set_meta("terrain_shader_preparation",{"shader":shader,"configured_mask":Variants.configured_mask(settings),"seconds":(Time.get_ticks_usec()-start)/1000000.0,"large_image_banks_loaded_before_preparation":ResourceLoader.has_cached("res://materials/terrain.tres")})
	viewport.queue_free();await tree.process_frame;await tree.process_frame
	return shader
