extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var source:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader")
	assert(source.contains("if(CUSTOM0.w<0.0)") and source.contains("UV.y=(round(b.z*255.0)-127.0)/254.0"))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(640,640));root.size=Vector2i(640,640)
	var shader:=Shader.new();shader.code='''shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
#include "res://shaders/terrain_control_decode.gdshaderinc"
varying float verified;
void vertex(){vec3 b=unpack_control24(UV.y),j=unpack_control24(-CUSTOM0.w-1.0);float actual[8];actual[0]=b.x;actual[1]=b.y;actual[2]=(round(b.z*255.0)-127.0)/254.0;actual[3]=j.x;actual[4]=j.y;actual[5]=j.z;actual[6]=CUSTOM0.w<0.0?1.0:0.0;actual[7]=b.z;verified=abs(actual[int(UV.x+.5)]-CUSTOM1.x)<.001?1.0:0.0;}
void fragment(){ALBEDO=verified>.5?vec3(0,1,0):vec3(1,0,0);}
'''
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var controls:=PackedFloat32Array();var expected_controls:=PackedFloat32Array();var indices:=PackedInt32Array()
	for row in range(8):
		for col in range(8):
			var bytes:=Vector3i.ZERO if row==0 else (Vector3i(255,255,254) if row==1 else Vector3i(row*47%256,row*73%256,row*197%255))
			var actual:Array=[float(bytes.x)/255,float(bytes.y)/255,float(bytes.z-127)/254,float(bytes.x)/255,float(bytes.y)/255,float(bytes.z)/255,1.0,float(bytes.z)/255]
			if row==1:actual[3]=1.0;actual[4]=1.0;actual[5]=1.0
			var expected:float=actual[col]
			if row==7 and col==7:expected+=.15
			var encoded:float=bytes.x+bytes.y*256+bytes.z*65536;var offset:int=vertices.size();var x:float=col-4;var y:float=4-row
			var jungle_encoded:float=16777215 if row==1 else encoded
			for point in [Vector2(x+.04,y-.04),Vector2(x+.96,y-.04),Vector2(x+.96,y-.96),Vector2(x+.04,y-.96)]:
				vertices.append(Vector3(point.x,point.y,0));uvs.append(Vector2(col,encoded));controls.append_array(PackedFloat32Array([0,0,0,-jungle_encoded-1]));expected_controls.append_array(PackedFloat32Array([expected,0,0,0]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM0]=controls;arrays[Mesh.ARRAY_CUSTOM1]=expected_controls;arrays[Mesh.ARRAY_INDEX]=indices
	var flags:int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var im:Image=root.get_texture().get_image();var errors:int=0;var negative:bool=false
	for row in range(8):
		for col in range(8):
			var pixel:Color=im.get_pixel(int((col+.5)*im.get_width()/8),int((row+.5)*im.get_height()/8));var intentional:bool=row==7 and col==7
			var ok:bool=(pixel.r>.98 and pixel.g<.02) if intentional else (pixel.g>.98 and pixel.r<.02)
			if intentional:negative=ok
			if not ok:errors+=1
	im.save_png("res://tools/badlands/artifacts/gpu_channels.png")
	var report:Dictionary={"actual_render":true,"positive_tiles":63,"negative_tiles":1,"negative_detected":negative,"errors":errors,"adapter":RenderingServer.get_video_adapter_name()}
	FileAccess.open("res://tools/badlands/artifacts/gpu_channels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BADLANDS_GPU_CHANNELS ",report);scene.queue_free();await process_frame;quit(0 if errors==0 and negative else 1)
