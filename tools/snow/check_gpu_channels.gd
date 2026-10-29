extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Actual rendering required");quit(2);return
	DisplayServer.window_set_size(Vector2i(960,640));root.size=Vector2i(960,640)
	var shader:=Shader.new();shader.code='''shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
#include "res://shaders/desert_control_decode.gdshaderinc"
#include "res://shaders/snow_control_decode.gdshaderinc"
varying float verified;
void vertex(){vec4 a,b,c;snow_decode(CUSTOM3,a,b,c);int channel=int(UV.x+.5);float actual=channel<4?a[channel]:(channel<8?b[channel-4]:c[channel-8]);verified=abs(actual-UV.y/255.0)<.001?1.0:0.0;}
void fragment(){ALBEDO=verified>.5?vec3(0,1,0):vec3(1,0,0);}
'''
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var packed:=PackedFloat32Array();var indices:=PackedInt32Array()
	for row in range(8):
		for col in range(12):
			var bytes:=PackedInt32Array()
			for i in range(12):bytes.append(0 if row==0 else (255 if row==1 else (row*47+i*73)%256))
			var expected:int=bytes[col]
			if row==7 and col==7:bytes[7]=(bytes[7]+37)%256
			var encoded:=PackedFloat32Array()
			for i in range(4):encoded.append(bytes[i*3]+bytes[i*3+1]*256+bytes[i*3+2]*65536)
			var offset:int=vertices.size();var x:float=col-6;var y:float=4-row
			for point in [Vector2(x+.04,y-.04),Vector2(x+.96,y-.04),Vector2(x+.96,y-.96),Vector2(x+.04,y-.96)]:
				vertices.append(Vector3(point.x,point.y,0));uvs.append(Vector2(col,expected));packed.append_array(encoded)
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM3]=packed;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	var scene:=Node3D.new();root.add_child(scene)
	var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var errors:int=0;var negative:bool=false
	for row in range(8):
		for col in range(12):
			var pixel:Color=image.get_pixel(col*80+40,row*80+40);var intentional:bool=row==7 and col==7
			var ok:bool=(pixel.r>.98 and pixel.g<.02) if intentional else (pixel.g>.98 and pixel.r<.02)
			if intentional:negative=ok
			if not ok:errors+=1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/snow/artifacts"))
	image.save_png("res://tools/snow/artifacts/gpu_channels.png")
	var result:Dictionary={"positive_tiles":95,"negative_tiles":1,"errors":errors,"negative_detected":negative,"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
	var file:=FileAccess.open("res://tools/snow/artifacts/gpu_channels.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SNOW_GPU_CHANNELS ",JSON.stringify(result));quit(0 if errors==0 and negative else 1)
