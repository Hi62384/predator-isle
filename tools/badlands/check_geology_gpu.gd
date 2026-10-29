extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var scaled:bool=OS.get_cmdline_user_args().has("scaled")
	var height_scale:float=2.25 if scaled else 1.0;var sea_level:float=17 if scaled else 0.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(640,640));root.size=Vector2i(640,640)
	var source:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	var begin:int=source.find("float badlands_coordinate(){");var end:int=source.find("void badlands_projected(",begin)
	assert(begin>=0 and end>begin)
	# Execute the actual production geology functions, not a test-side copy.
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled,fog_disabled; varying vec3 world_position; uniform float badlands_strata_metres=84.0; uniform float badlands_thickness_variation=.16; uniform vec2 badlands_strata_dip=vec2(.018,.012); uniform float badlands_fold_strength=1.0; uniform float badlands_height_multiplier=1.0; uniform float water_level=0.0; "+source.substr(begin,end-begin)+"\nvoid vertex(){world_position=CUSTOM0.xyz;}\nvoid fragment(){float phase=badlands_phase();float error=abs(phase-UV.x);error=min(error,5.0-error);bool ok=error<.003 && abs(badlands_hardness(phase)-UV.y)<.04;ALBEDO=ok?vec3(0,1,0):vec3(1,0,0);}\n"
	var sampler=preload("res://scripts/badlands_sampler.gd").new();sampler.settings=load("res://config/biomes/badlands_settings.tres")
	var vertices:=PackedVector3Array();var controls:=PackedFloat32Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	for row in range(8):
		for col in range(8):
			var location:=Vector3((col-4)*98304+320,row*149.5,(row-4)*65792+640)
			var expected:Vector2=sampler.strata(Vector2(location.x,location.z),location.y)
			location.y=location.y*height_scale+sea_level
			if row==7 and col==7:expected.x=fposmod(expected.x+1,5)
			var offset:int=vertices.size();var x:float=col-4;var y:float=4-row
			for point:Vector2 in [Vector2(x+.04,y-.04),Vector2(x+.96,y-.04),Vector2(x+.96,y-.96),Vector2(x+.04,y-.96)]:
				vertices.append(Vector3(point.x,point.y,0));uvs.append(expected);controls.append_array(PackedFloat32Array([location.x,location.y,location.z,0]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM0]=controls;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;scene.add_child(node)
	material.set_shader_parameter("badlands_height_multiplier",height_scale);material.set_shader_parameter("water_level",sea_level)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var failures:Array=[];var detected:bool=false
	for row in range(8):
		for col in range(8):
			var pixel:Color=image.get_pixel((col+.5)*image.get_width()/8,(row+.5)*image.get_height()/8)
			var negative:bool=row==7 and col==7;var ok:bool=pixel.r>.98 and pixel.g<.02 if negative else pixel.g>.98 and pixel.r<.02
			if negative:detected=ok
			if not ok:failures.append(Vector2i(col,row))
	var suffix:String="_scaled" if scaled else ""
	image.save_png("res://tools/badlands/artifacts/check_geology_gpu"+suffix+".png")
	var report:Dictionary={"positive_cases":63,"intentional_negative_cases":1,"negative_detected":detected,"failures":failures,"actual_render":true,"adapter":RenderingServer.get_video_adapter_name(),"production_functions":true,"height_multiplier":height_scale,"water_level":sea_level,"shader_sha256":FileAccess.get_sha256("res://shaders/badlands_material.gdshaderinc")}
	FileAccess.open("res://tools/badlands/artifacts/check_geology_gpu"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_GEOLOGY_GPU ",report)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() and detected else 1)
