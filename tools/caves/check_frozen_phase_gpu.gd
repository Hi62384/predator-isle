extends "res://tools/biome_extensions/check_all.gd"
const Adapter=preload("res://scripts/caves/frozen_surface.gd")
var captures:Dictionary={}
func panel(low:float,high:float,origin:float,material:ShaderMaterial)->MeshInstance3D:
	var points:Array=[Vector3(low-origin,-16,0),Vector3(low-origin,16,0),Vector3(high-origin,16,0),Vector3(high-origin,-16,0)];var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	for index:int in [0,1,2,0,2,3]:vertices.append(points[index]);normals.append(Vector3.BACK);colors.append(Color(.65,.22,.95,1))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(origin,0,0);node.material_override=material;return node
func picture(view:SubViewport,label:String)->Image:
	for frame in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=view.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_frozen_phase_"+label+".png";check(image.save_png(path)==OK,"Native physical ice phase image "+label);captures[path]=FileAccess.get_sha256(path);return image
func maximum_error(a:Image,b:Image)->int:
	var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var result:int=0;var channels:int=left.size()/(a.get_width()*a.get_height())
	for y in range(2,a.get_height()-2):
		for x in range(2,a.get_width()-2):
			for channel in range(3):var i:int=(y*a.get_width()+x)*channels+channel;result=maxi(result,absi(int(left[i])-int(right[i])))
	return result
func source(old_macro:bool)->String:
	var code:String=FileAccess.get_file_as_string("res://shaders/cave_frozen_feature.gdshader");code=code.substr(0,code.find("void fragment()"));code=code.replace("diffuse_burley,specular_schlick_ggx","unshaded,fog_disabled,cull_disabled")
	if old_macro:
		var include:String=FileAccess.get_file_as_string("res://shaders/cave_frozen_surface.gdshaderinc")
		for pair:Array in [["(6.283185307179586/384.0)",".021"],["(6.283185307179586/480.0)",".013"],["(6.283185307179586/320.0)",".017"],["(6.283185307179586/60.0)",".11"],["(6.283185307179586/80.0)",".073"],["(6.283185307179586/96.0)",".09"]]:include=include.replace(pair[0],pair[1])
		code=code.replace("#include \"res://shaders/cave_frozen_surface.gdshaderinc\"",include)
	return code+"void fragment(){vec3 base,mapped;float rough;cave_frozen_sample(ice_position,ice_texture_position,normalize(ice_normal),dFdx(ice_position),dFdy(ice_position),base,rough,mapped);ALBEDO=base;}"
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://shaders/cave_frozen_feature.gdshader","res://shaders/cave_frozen_surface.gdshaderinc","res://shaders/cave_vertex_projection.gdshaderinc","res://scripts/caves/frozen_surface.gd"]:guards[path]=FileAccess.get_sha256(path)
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var world:=Node3D.new();viewport.add_child(world);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=32;camera.near=.01;camera.far=50000;world.add_child(camera)
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=source(false);material.shader=shader;Adapter.new().bind(material,{});var original:=ShaderMaterial.new();var old_shader:=Shader.new();old_shader.code=source(true);original.shader=old_shader;Adapter.new().bind(original,{})
	var records:Array=[];var positive_negative:int=0;var worst:int=0
	for boundary:float in [3840.0,-3840.0,7680.0,-7680.0]:
		for metres:float in [6.0,7.25,.5]:
			material.set_shader_parameter("cave_frozen_texture_metres",metres);original.set_shader_parameter("cave_frozen_texture_metres",metres);camera.position=Vector3(boundary,0,100);camera.look_at(Vector3(boundary,0,0));var tag:String=str(int(boundary))+"_"+str(metres).replace(".","p")
			var whole:MeshInstance3D=panel(boundary-32,boundary+32,boundary-64,material);var first:MeshInstance3D=panel(boundary-32,boundary,boundary-64,material);var second:MeshInstance3D=panel(boundary,boundary+32,boundary,material);world.add_child(whole);world.add_child(first);world.add_child(second);first.visible=false;second.visible=false
			var reference:Image=await picture(viewport,tag+"_whole");whole.visible=false;first.visible=true;second.visible=true;var split:Image=await picture(viewport,tag+"_split");var error:int=maximum_error(reference,split);worst=maxi(worst,error);check(error<=2,"Same physical ice across independent node/chunk/common macro-phase origins,including non-integer metre setting;predeclared2byte bound")
			whole.visible=true;first.visible=false;second.visible=false;var repeated:Image=await picture(viewport,tag+"_whole_return");check(reference.get_data()==repeated.get_data(),"Exact whole-patch physical shader image return")
			whole.material_override=original;var negative_whole:Image=await picture(viewport,tag+"_old_macro_whole");whole.visible=false;first.material_override=original;second.material_override=original;first.visible=true;second.visible=true;var negative_split:Image=await picture(viewport,tag+"_old_macro_split");var old_error:int=maximum_error(negative_whole,negative_split)
			if old_error>2:positive_negative+=1
			records.append({"boundary_m":boundary,"texture_metres":metres,"maximum_current_rgb_byte_error":error,"original_macro_negative_error":old_error});whole.queue_free();first.queue_free();second.queue_free();await process_frame
	check(positive_negative>=8,"Original non-periodic macro frequencies are live visible wrong-phase negative controls,not a black/empty fixture")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable physical Frozen shader phase "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_phase_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"worst_current_byte_error":worst,"positive_original_macro_negatives":positive_negative,"scope":"Native physical ice helper and actual production feature vertex phase,whole-vs-two independent chunk nodes across positive/negative3840/7680m wraps;6m,7.25m,.5m texture settings. Original macro arithmetic retained as private live wrong-phase controls. Predeclared2/255RGB bound;exact whole returns. Explicit unshaded helper panel isolates texture/macro coordinates,not full-world lighting,art,FPS or complete Frozen acceptance."},"  "));print("FROZEN_PHASE_GPU ",checks," worst=",worst," negatives=",positive_negative," failures=",failures);viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
