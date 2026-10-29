extends SceneTree
func _initialize()->void:call_deferred("run")
func color_at(bytes:PackedByteArray,width:int,slot:int,x:int,z:int)->Vector4:
	var index:int=(z*width+slot*33+x)*4
	return Vector4(bytes[index],bytes[index+1],bytes[index+2],bytes[index+3])/255
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(640,640));root.size=Vector2i(640,640)
	var source:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	var start:int=source.find("vec4 badlands_palette_controls(){");var end:int=source.find("float badlands_layer(",start);assert(start>=0 and end>start)
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform sampler2D extension_payload:filter_linear,repeat_disable;uniform float chunk_size_metres=256.0;uniform int badlands_palette_slot=0;varying vec3 forest_local_position;varying vec4 expected;"+source.substr(start,end-start)+"void vertex(){forest_local_position=vec3(CUSTOM1.x,0,CUSTOM1.y);expected=CUSTOM0;}void fragment(){vec4 error=abs(badlands_palette_controls()-expected);ALBEDO=max(max(error.x,error.y),max(error.z,error.w))<.006?vec3(0,1,0):vec3(1,0,0);}\n"
	var failures:Array=[];var negatives:int=0
	for slot:int in [0,8]:
		var width:int=33*(slot+1);var bytes:=PackedByteArray();bytes.resize(width*33*4)
		for z in range(33):
			for x in range(33):
				for channel in range(4):bytes[(z*width+slot*33+x)*4+channel]=(x*(13+channel*7)+z*(31+channel*11)+channel*23)%256
		var texture:=ImageTexture.create_from_image(Image.create_from_data(width,33,false,Image.FORMAT_RGBA8,bytes))
		var vertices:=PackedVector3Array();var controls:=PackedFloat32Array();var positions:=PackedFloat32Array();var indices:=PackedInt32Array()
		for row in range(8):
			for col in range(8):
				var gx:float=float(col)*32/7;var gz:float=float(row)*32/7;var ix:int=mini(floori(gx),31);var iz:int=mini(floori(gz),31)
				var expected:Vector4=color_at(bytes,width,slot,ix,iz).lerp(color_at(bytes,width,slot,ix+1,iz),gx-ix).lerp(color_at(bytes,width,slot,ix,iz+1).lerp(color_at(bytes,width,slot,ix+1,iz+1),gx-ix),gz-iz)
				if row==7 and col==7:expected.x=0 if expected.x>.5 else 1
				var offset:int=vertices.size();var x:float=col-4;var y:float=4-row
				for p:Vector2 in [Vector2(x+.04,y-.04),Vector2(x+.96,y-.04),Vector2(x+.96,y-.96),Vector2(x+.04,y-.96)]:
					vertices.append(Vector3(p.x,p.y,0));controls.append_array(PackedFloat32Array([expected.x,expected.y,expected.z,expected.w]));positions.append_array(PackedFloat32Array([gx*8,gz*8,0,0]))
				indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_CUSTOM0]=controls;arrays[Mesh.ARRAY_CUSTOM1]=positions;arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("extension_payload",texture);material.set_shader_parameter("badlands_palette_slot",slot);node.material_override=material;scene.add_child(node)
		var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image()
		for row in range(8):
			for col in range(8):
				var color:Color=image.get_pixel((col+.5)*image.get_width()/8,(row+.5)*image.get_height()/8);var negative:bool=row==7 and col==7
				var ok:bool=color.r>.98 and color.g<.02 if negative else color.g>.98 and color.r<.02
				if negative and ok:negatives+=1
				if not ok:failures.append([slot,col,row])
		image.save_png("res://tools/badlands/artifacts/check_palette_gpu_"+str(slot)+".png");scene.queue_free();await process_frame
	var report:Dictionary={"positive_cases":126,"negative_cases":2,"negative_detected":negatives,"failures":failures,"actual_production_function":true,"actual_render":true,"shader_sha256":FileAccess.get_sha256("res://shaders/badlands_material.gdshaderinc"),"adapter":RenderingServer.get_video_adapter_name()}
	FileAccess.open("res://tools/badlands/artifacts/check_palette_gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_PALETTE_GPU ",report);quit(0 if failures.is_empty() and negatives==2 else 1)
