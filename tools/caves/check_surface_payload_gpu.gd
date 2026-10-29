extends "res://tools/biome_extensions/check_all.gd"
const Payload=preload("res://tools/caves/cave_surface_payload_candidate.gd")
const SurfaceShader=preload("res://tools/caves/cave_surface_shader_candidate.gd")
func pack(a:int,b:int,c:int)->float:return float(a+256*b+65536*c)
func shader_code(original:String,candidate:bool)->String:
	var source:String=SurfaceShader.code(original) if candidate else original;var end:int=source.find(SurfaceShader.END);assert(end>0);source=source.substr(0,end)
	if not candidate:source=source.replace("void vertex() {",SurfaceShader.uniforms()+"\nvoid vertex() {")
	source=source.replace("render_mode diffuse_burley, specular_schlick_ggx;","render_mode unshaded,cull_disabled,fog_disabled;").replace("void vertex() {","varying float transport_error;\nvoid vertex() {")
	source+=SurfaceShader.load_texels().replace("vec4 surface_p","vec4 verify_p").replace("surface_base","verify_base")+"\n transport_error=0.0;\n";var offset:int=0
	for item:Array in SurfaceShader.LAYOUT:
		for i in range(item[1]):
			var actual:String=item[0]+("[%d]"%i if item[1]>1 else "");var expected:String=SurfaceShader.component(offset).replace("surface_p","verify_p");source+=" transport_error=max(transport_error,abs("+actual+"-"+expected+"));\n";offset+=1
	return source+"\n}\nvoid fragment(){ALBEDO=transport_error<.00001?vec3(0,1,0):vec3(1,0,0);}\n"
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_surface_payload_gpu.gd","res://tools/caves/cave_surface_payload_candidate.gd","res://tools/caves/cave_surface_shader_candidate.gd","res://shaders/terrain_biomes.gdshader","res://shaders/terrain_control_decode.gdshaderinc","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=73921
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",10)
	b._configure_noise();var actual:Array=b.build(Vector2i(58,-17),8);var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array();arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array();arrays[Mesh.ARRAY_COLOR]=PackedColorArray();arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array();arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array()
	for slot in range(Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM3+1):arrays[slot]=PackedFloat32Array()
	for tile in range(64):
		var index:int=tile%actual[Mesh.ARRAY_VERTEX].size();var c0:PackedFloat32Array=Payload.channel(actual,Mesh.ARRAY_CUSTOM0,index,4);var c1:PackedFloat32Array=Payload.channel(actual,Mesh.ARRAY_CUSTOM1,index,4);var c2:PackedFloat32Array=Payload.channel(actual,Mesh.ARRAY_CUSTOM2,index,4);var c3:PackedFloat32Array=Payload.channel(actual,Mesh.ARRAY_CUSTOM3,index,4);var uv:Vector2=actual[Mesh.ARRAY_TEX_UV][index];var uv2:Vector2=actual[Mesh.ARRAY_TEX_UV2][index];var color:Color=actual[Mesh.ARRAY_COLOR][index]
		if tile>=32:
			var flags:int=tile-32;c0=PackedFloat32Array([-pack(21,23,29)-1,pack(31,37,41),pack(43,47,53),-pack(59,61,67)-1]);c1=PackedFloat32Array([-pack(71,73,79)-1,pack(83,89,97),-pack(101,103,107)-1,-pack(109,113,127)-1]);c2=PackedFloat32Array([-pack(149,151,157)-1,pack(163,167,173),pack(179,181,191),pack(193,197,199)]);c3=PackedFloat32Array([-pack(211,223,227)-1,pack(229,233,239),pack(241,251,253),pack(255,254,252)]);uv=Vector2(25.123456,pack(14,42,129));uv2=Vector2(pack(3,7,11),pack(13,17,19));color=Color(.123456,.234567,.345678,.456789)
			if flags&1==0:c0[0]=.123456;c0[1]=.234567;c0[2]=.345678;uv2=Vector2(.314159,.271828)
			if flags&2==0:c0[3]=pack(59,61,67);uv.y=.123456
			if flags&4==0:c1[2]=.123456;c1[3]=.234567
			elif flags&8==0:c1[3]=pack(131,137,139)
			if flags&16==0:c1[0]=pack(71,73,79);c2[0]=pack(149,151,157);c3[0]=pack(211,223,227)
		var x:float=tile%8-4;var y:float=4-tile/8
		for point:Vector2 in [Vector2(x+.02,y-.02),Vector2(x+.98,y-.02),Vector2(x+.98,y-.98),Vector2(x+.02,y-.02),Vector2(x+.98,y-.98),Vector2(x+.02,y-.98)]:
			arrays[Mesh.ARRAY_VERTEX].append(Vector3(point.x,point.y,0));arrays[Mesh.ARRAY_NORMAL].append(Vector3.BACK);arrays[Mesh.ARRAY_COLOR].append(color);arrays[Mesh.ARRAY_TEX_UV].append(uv);arrays[Mesh.ARRAY_TEX_UV2].append(uv2)
			for slot in range(4):arrays[Mesh.ARRAY_CUSTOM0+slot].append_array([c0,c1,c2,c3][slot])
	var mesh:=ArrayMesh.new();var format:int=0
	for slot in range(4):format|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<(Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT+slot*Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	var viewport:=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var scene:=Node3D.new();viewport.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;scene.add_child(node);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	var original:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader");var captures:Dictionary={};var records:Array=[]
	for normalized:bool in [false,true]:
		var semantic:=PackedFloat32Array()
		for index in range(arrays[Mesh.ARRAY_VERTEX].size()):semantic.append_array(Payload.decode(arrays,index,normalized))
		for mode:int in [0,1,2]:
			var values:PackedFloat32Array=semantic.duplicate()
			if mode==2:
				for vertex in range(arrays[Mesh.ARRAY_VERTEX].size()):values[vertex*68]+=.25
			var data:Dictionary=Payload.atlas(values);var texture:=ImageTexture.create_from_image(Image.create_from_data(data.width,data.height,false,Image.FORMAT_RGBAF,data.bytes));var shader:=Shader.new();shader.code=shader_code(original,mode==1);var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("cave_surface_payload",texture);material.set_shader_parameter("extension_payload_enabled",normalized);node.material_override=material
			for frame in range(8):await process_frame
			await RenderingServer.frame_post_draw;var picture:Image=viewport.get_texture().get_image();var green:int=0;var red:int=0
			for row in range(8):
				for col in range(8):
					var pixel:Color=picture.get_pixel(col*32+16,row*32+16);green+=int(pixel.g>.98 and pixel.r<.02);red+=int(pixel.r>.98 and pixel.g<.02)
			check(red==64 if mode==2 else green==64,"All67actual semantic channels match native decode;negative atlas corruption detected: normalized%s/mode%d"%[normalized,mode]);var capture:String="res://tools/biome_extensions/artifacts/cave_surface_gpu_%d_%d.png"%[int(normalized),mode];check(picture.save_png(capture)==OK,"Saved complete native surface payload diagnostic");captures[capture]=FileAccess.get_sha256(capture);records.append({"extension_normalization":normalized,"mode":mode,"green_tiles":green,"red_tiles":red});print("SURFACE_GPU ",records[-1])
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native payload source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_payload_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"production_registration":false,"scope":"PRIVATE actual native terrain vertex-decode procedure versus CPU semantic transport and reconstructed vertex shader.67semantic scalars,32actual mixed-world vertex records plus32nested wrapper combinations,normalized extension mode on/off,128deliberately corrupted atlas tile controls. Constant semantic triangle inputs isolate decode,not full PBR image/portal seam/streaming acceptance."},"  "));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
