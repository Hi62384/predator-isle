extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,640));root.size=Vector2i(960,640)
	var shader:=Shader.new();shader.code='''shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
#include "res://shaders/terrain_control_decode.gdshaderinc"
varying float verified;
void vertex(){int k=int(UV.x+.5);float values[2];values[0]=-CUSTOM1.z-1.0;values[1]=-CUSTOM1.w-1.0;float actual=unpack_control24(values[k/3])[k%3];verified=abs(actual-UV.y/255.0)<.001?1.0:0.0;}
void fragment(){ALBEDO=verified>.5?vec3(0,1,0):vec3(1,0,0);}
'''
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var packed:=PackedFloat32Array();var indices:=PackedInt32Array()
	for row in range(8):
		for col in range(6):
			var bytes:=Vector3i(0,0,0) if row==0 else (Vector3i(255,255,255) if row==1 else Vector3i((row*47)%256,(row*73)%256,(row*197)%256))
			var expected:int=bytes[col%3]
			if row==7 and col==5:bytes[2]=(bytes[2]+37)%256
			var encoded:float=bytes.x+bytes.y*256+bytes.z*65536;var offset:int=vertices.size();var x:float=col*2-6;var y:float=4-row
			for point in [Vector2(x+.04,y-.04),Vector2(x+1.96,y-.04),Vector2(x+1.96,y-.96),Vector2(x+.04,y-.96)]:
				vertices.append(Vector3(point.x,point.y,0));uvs.append(Vector2(col,expected));packed.append_array(PackedFloat32Array([0,0,-encoded-1,-encoded-1]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM1]=packed;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var errors:int=0;var negative:bool=false
	for row in range(8):
		for col in range(6):
			var pixel:Color=image.get_pixel(int((col+.5)*image.get_width()/6),int((row+.5)*image.get_height()/8));var intentional:bool=row==7 and col==5
			var ok:bool=(pixel.r>.98 and pixel.g<.02) if intentional else (pixel.g>.98 and pixel.r<.02)
			if intentional:negative=ok
			if not ok:errors+=1
	image.save_png("res://tools/beach/artifacts/gpu_channels.png")
	var report:Dictionary={"positive_tiles":47,"negative_tiles":1,"errors":errors,"negative_detected":negative,"actual_render":true,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://tools/beach/artifacts/gpu_channels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BEACH_GPU_CHANNELS ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if errors==0 and negative else 1)
