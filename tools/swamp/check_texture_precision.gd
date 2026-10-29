extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(640,640));root.size=Vector2i(640,640)
	var shader:=Shader.new();shader.code='''shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
#include "res://shaders/terrain_control_decode.gdshaderinc"
varying float verified;
void vertex(){int p=int(round(UV.x*4.0));int o=int(round(CUSTOM1.x*4.0));int r=abs(o)%p;if(o<0 && r>0)r=p-r;float phase=float(r)*.25;verified=abs(phase-UV.y)<.0001?1.0:0.0;}
void fragment(){ALBEDO=verified>.5?vec3(0,1,0):vec3(1,0,0);}
'''
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var packed:=PackedFloat32Array();var indices:=PackedInt32Array()
	for row in range(8):
		for col in range(8):
			var origin:float=[0,256,-256,-625408,3642624,3642880,4194048,-3642624][row]
			var period:float=[.5,.75,1,1.5,3,3.5,10,10.25][col]
			var expected:float=fposmod(origin,period)
			if row==7 and col==7:expected+=.25
			var offset:int=vertices.size();var x:float=col-4;var y:float=4-row
			for point in [Vector2(x+.04,y-.04),Vector2(x+.96,y-.04),Vector2(x+.96,y-.96),Vector2(x+.04,y-.96)]:
				vertices.append(Vector3(point.x,point.y,0));uvs.append(Vector2(period,expected));packed.append_array(PackedFloat32Array([origin,0,0,0]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM1]=packed;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();node.mesh=mesh;var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,5);scene.add_child(camera);camera.current=true
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var errors:int=0;var negative:bool=false
	for row in range(8):
		for col in range(8):
			var pixel:Color=image.get_pixel(int((col+.5)*image.get_width()/8),int((row+.5)*image.get_height()/8));var intentional:bool=row==7 and col==7
			var ok:bool=(pixel.r>.98 and pixel.g<.02) if intentional else (pixel.g>.98 and pixel.r<.02)
			if intentional:negative=ok
			if not ok:errors+=1
	image.save_png("res://tools/swamp/artifacts/texture_precision.png")
	var report:Dictionary={"positive_tiles":63,"negative_tiles":1,"errors":errors,"negative_detected":negative,"actual_render":true,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://tools/swamp/artifacts/texture_precision.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SWAMP_TEXTURE_PRECISION ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if errors==0 and negative else 1)
