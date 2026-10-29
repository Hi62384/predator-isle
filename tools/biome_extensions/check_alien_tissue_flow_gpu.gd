extends SceneTree
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func texture_for(bytes:PackedByteArray,rows:int,columns:int)->ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(columns,rows,false,Image.FORMAT_RGBAF,bytes))
func run()->void:
	verify(DisplayServer.get_name()!="headless","Actual GPU required")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(768,256));root.size=Vector2i(768,256);root.content_scale_size=Vector2i(768,256)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_alien_tissue_transport.json"));assert(fixture.passed)
	var guards:Dictionary=fixture.source_sha256.duplicate();guards["res://tools/biome_extensions/artifacts/check_alien_tissue_transport.json"]=FileAccess.get_sha256("res://tools/biome_extensions/artifacts/check_alien_tissue_transport.json")
	for path:String in ["res://tools/biome_extensions/check_alien_tissue_flow_gpu.gd","res://shaders/biome_structures.gdshader","res://materials/biological_colors_v3.tres","res://materials/biological_color_nerve_v3.res"]:guards[path]=FileAccess.get_sha256(path)
	var shell:String=FileAccess.get_file_as_string("res://shaders/biome_structures.gdshader");var begin:int=shell.find("float field(vec2 p)");var end:int=shell.find("#include",begin);assert(begin>=0 and end>begin)
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform vec3 sample_site;uniform vec3 local_origin;varying vec3 world_position;varying vec3 forest_local_position;varying vec3 forest_origin;\n"+shell.substr(begin,end-begin)+'\n#include "res://shaders/biological_sampling.gdshaderinc"\n'+"void vertex(){world_position=sample_site+vec3((UV.x-.5)*8.0,0,(UV.y-.5)*8.0);forest_origin=local_origin;forest_local_position=world_position-forest_origin;}void fragment(){vec3 n=vec3(0,1,0);vec3 base=biological_sample(1,1.5,dFdx(forest_local_position),dFdy(forest_local_position),n,n);ALBEDO=alien_tissue_flow_enabled?alien_flow_color(base,n,dFdx(forest_local_position),dFdy(forest_local_position)):base;}"
	var scene:=Node3D.new();root.add_child(scene);var materials:Array[ShaderMaterial]=[]
	for column in range(3):
		var node:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE;node.mesh=quad;node.position=Vector3(column-1,0,0);scene.add_child(node)
		var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));node.material_override=material;materials.append(material)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=1;camera.position=Vector3(0,0,2);camera.current=true;scene.add_child(camera)
	var records:Array=[];var images:Dictionary={}
	for item:Dictionary in fixture.cases:
		if item.profile!=0:continue
		var components:PackedStringArray=String(item.cell).trim_prefix("(").trim_suffix(")").split(",");var cell:=Vector2i(int(components[0]),int(components[1]));var point:=Vector2(cell)*256+Vector2(128,128)
		var b=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(int(item.seed),true);var field=b._extras[7]
		var child_origin:Vector2=Vector2(cell)*256;var parent_origin:=Vector2(floorf(point.x/1024)*1024,floorf(point.y/512)*512)
		var child:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").atlas(field,child_origin,256,32);var parent:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").rectangle(field,parent_origin,Vector2(1024,512),Vector2i(128,64))
		assert(not child.data.is_empty() and not parent.data.is_empty())
		var negative:PackedFloat32Array=child.data.to_float32_array()
		for index in range(0,negative.size(),4):
			if negative[index+2]>0:negative[index]+=.37
		for column in range(3):
			var use_parent:bool=column==1;var origin:Vector2=parent_origin if use_parent else child_origin;var map:Dictionary=parent if use_parent else child
			materials[column].set_shader_parameter("alien_tissue_flow",texture_for(negative.to_byte_array() if column==2 else map.data,map.rows,map.columns));materials[column].set_shader_parameter("alien_tissue_flow_span",Vector2(1024,512) if use_parent else Vector2(256,256));materials[column].set_shader_parameter("local_origin",Vector3(origin.x,0,origin.y));materials[column].set_shader_parameter("sample_site",Vector3(point.x,0,point.y))
		var original:Image=null
		for phase in range(3):
			for material:ShaderMaterial in materials:material.set_shader_parameter("alien_tissue_flow_enabled",phase==1)
			for frame in range(12):await process_frame
			await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();verify(image.get_size()==Vector2i(768,256),"Exact native panel resolution")
			var maximum:float=0;var changed_negative:int=0
			for y in range(2,254):
				for x in range(2,254):
					var a:Color=image.get_pixel(x,y);var c:Color=image.get_pixel(x+256,y);var wrong:Color=image.get_pixel(x+512,y)
					maximum=maxf(maximum,maxf(absf(a.r-c.r),maxf(absf(a.g-c.g),absf(a.b-c.b))))
					if maxf(absf(a.r-wrong.r),maxf(absf(a.g-wrong.g),absf(a.b-wrong.b)))>2.0/255:changed_negative+=1
			verify(maximum<=2.0/255,"Same physical points under child/parent material origins within existing2/255 texture bound")
			if phase==0:original=image
			elif phase==1:verify(changed_negative>100,"GPU detects deliberately shifted finite-path UV,not a constant or unused atlas")
			else:verify(image.get_data()==original.get_data(),"Disabled/reference return is exactly identical")
			var path:String="res://tools/biome_extensions/artifacts/tissue_flow_gpu_%d_%d.png"%[int(item.seed),phase];verify(image.save_png(path)==OK,"Native panel image saved");images[path]=FileAccess.get_sha256(path)
			records.append({"seed":item.seed,"phase":phase,"world_point":str(point),"child_origin":str(child_origin),"parent_origin":str(parent_origin),"maximum_channel_difference":maximum,"negative_changed_pixels":changed_negative,"capture":path})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable GPU input "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_alien_tissue_flow_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":images,"cases":records,"scope":"Actual production shared tissue helper and RGBA32F data under two overlapping child/parent origins at three seeded on-land paths. Same physical pixels compare with unchanged2/255 texture bound;independent deliberately shifted arc negative must be detected,disabled-return full image exact. Nine native panels. Not actual terrain/controller or whole-world seam/scenic/performance acceptance."},"  "));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
