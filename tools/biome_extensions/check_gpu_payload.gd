extends SceneTree
var records:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var viewport:=SubViewport.new();viewport.size=Vector2i(128,128);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1;camera.position=Vector3(0,1,0);viewport.add_child(camera);camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	var node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE;node.mesh=plane;viewport.add_child(node)
	var include:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc");var begin:int=include.find("vec4 extension_texel");var end:int=include.find("vec3 extension_control")
	var function:String=include.substr(begin,end-begin)
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded;uniform sampler2D extension_payload:filter_linear,repeat_disable;uniform float chunk_size_metres=1.0;uniform int selected=0;varying vec3 forest_local_position;void vertex(){forest_local_position=VERTEX+vec3(.5,0,.5);}"+function+"void fragment(){vec4 s=extension_texel(selected);ALBEDO=s.xyz;}"
	var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;var failures:Array=[]
	for family_id in range(8):
		for case_id in range(3):
			var bytes:=PackedByteArray();bytes.resize(2*2*8*4);var expected:=Color(float([64,127,255][case_id])/255,.2,.4)
			for z in range(2):
				for x in range(2):
					var offset:int=(z*16+family_id*2+x)*4;bytes[offset]=[64,127,255][case_id];bytes[offset+1]=51;bytes[offset+2]=102
			var image:=Image.create_from_data(16,2,false,Image.FORMAT_RGBA8,bytes);material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(image));material.set_shader_parameter("selected",family_id)
			for frame in range(4):await process_frame
			await RenderingServer.frame_post_draw
			# This isolated Compatibility unshaded target exposes raw numeric RGB.
			# Applying sRGB decoding here would incorrectly transform the payload.
			var actual:Color=viewport.get_texture().get_image().get_pixel(64,64)
			var error:float=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
			if error>.015:failures.append([family_id,case_id,error,str(actual),str(expected)])
			records.append({"family":family_id,"case":case_id,"max_linear_error":error})
	# Intentionally corrupt the bound atlas, keeping the last expected value.
	var corrupt:=Image.create_empty(16,2,false,Image.FORMAT_RGBA8);material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(corrupt))
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var actual:Color=viewport.get_texture().get_image().get_pixel(64,64)
	var negative:bool=absf(actual.r-1)>.1
	if not negative:failures.append("Intentional corrupt atlas was not detected")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_gpu_payload.json",FileAccess.WRITE).store_string(JSON.stringify({"positive_cases":records,"failures":failures,"actual_source_function":true,"negative_control_detected":negative,"adapter":RenderingServer.get_video_adapter_name()},"\t"))
	print("EXTENSION_GPU_PAYLOAD ",records.size()," cases ",failures);viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
