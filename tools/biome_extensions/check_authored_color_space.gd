extends SceneTree
## Native production-expression comparison, including actual mesh COLOR input.
func _initialize()->void:call_deferred("run")
func error(a:Color,b:Color)->float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var baseline:bool=OS.get_cmdline_user_args().has("baseline")
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/lod_biome_extension_structures.gd"]=FileAccess.get_sha256("res://scripts/lod_biome_extension_structures.gd")
	for path:String in ["res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/badlands_material.gdshaderinc","res://tools/biome_extensions/check_authored_color_space.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var extension:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	var structure:String=FileAccess.get_file_as_string("res://shaders/biome_structures.gdshader")
	var base:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	var regex:=RegEx.new();assert(regex.compile("vec3 badlands_working_color\\(vec3 srgb\\)\\{[\\s\\S]*?\\n\\}")==OK)
	var helper:RegExMatch=regex.search(base);assert(helper!=null)
	var terrain_expression:String=extension.get_slice("luminance=dot(surface.rgb,vec3(.3,.5,.2));color=",1).get_slice("*(.5+luminance*.9)",0)
	assert(not terrain_expression.is_empty() and not terrain_expression.contains(";"),"Production terrain colour expression located")
	var structure_expression:String=structure.get_slice(" ALBEDO=",1).get_slice("*(.75+grain*.12+age*.13)",0)
	assert(not structure_expression.is_empty() and not structure_expression.contains(";"),"Production structure colour expression located")
	var structure_helper:String=""
	if structure.contains("vec3 structure_working_color("):
		assert(regex.compile("vec3 structure_working_color\\(vec3 srgb\\)\\{[\\s\\S]*?\\n\\}")==OK)
		var found:RegExMatch=regex.search(structure);assert(found!=null);structure_helper=found.get_string()
	var colors:Array[Color]=[Color(.54,.53,.51),Color(.48,.43,.36),Color(.22,.23,.23),Color(.19,.15,.105),Color(.48,.43,.35),Color(.63,.61,.55),Color(.46,.26,.13),Color(.24,.12,.11)]
	var pixels:=Image.create_empty(1,8,false,Image.FORMAT_RGB8);var authored:=PackedVector3Array()
	var vertices:=PackedVector3Array();var vertex_colors:=PackedColorArray();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for row in range(8):
		pixels.set_pixel(0,row,colors[row]);var color:Color=pixels.get_pixel(0,row);authored.append(Vector3(color.r,color.g,color.b))
		var offset:int=vertices.size();var top:float=4-row
		for p:Vector2 in [Vector2(-4,top),Vector2(4,top),Vector2(4,top-1),Vector2(-4,top-1)]:
			vertices.append(Vector3(p.x,p.y,0));vertex_colors.append(color);uv.append(Vector2((p.x+4)/8,(4-p.y)/8))
		indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=vertex_colors;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform sampler2D reference:source_color,filter_nearest,repeat_disable;uniform vec3 authored[8];\n"+helper.get_string()+"\n"+structure_helper+"\nvoid fragment(){int row=clamp(int(UV.y*8.0),0,7);vec3 tint=authored[row];vec3 target=texture(reference,vec2(.5,UV.y)).rgb;vec3 terrain="+terrain_expression+";vec3 structure="+structure_expression+";vec3 wrong=OUTPUT_IS_SRGB?pow(tint,vec3(2.2)):tint;ALBEDO=UV.x<.25?target:(UV.x<.5?terrain:(UV.x<.75?structure:wrong));}"
	DisplayServer.window_set_size(Vector2i(512,512));root.size=Vector2i(512,512)
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("reference",ImageTexture.create_from_image(pixels));material.set_shader_parameter("authored",authored);node.material_override=material;scene.add_child(node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,2);camera.current=true;scene.add_child(camera)
	for i in range(15):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var records:Array=[];var failures:Array=[];var wrong_detected:int=0;var legacy_detected:int=0
	for row in range(8):
		var y:int=int((row+.5)*512/8);var target:Color=image.get_pixel(64,y)
		var terrain_error:float=error(target,image.get_pixel(192,y));var structure_error:float=error(target,image.get_pixel(320,y));var wrong_error:float=error(target,image.get_pixel(448,y))
		if terrain_error>2.0/255 or structure_error>2.0/255:failures.append(row)
		if terrain_error>.015 and structure_error>.015:legacy_detected+=1
		if wrong_error>.015:wrong_detected+=1
		records.append({"family":TerrainSettings.EXTENSION_KEYS[row],"terrain_error":terrain_error,"structure_error":structure_error,"wrong_space_error":wrong_error})
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during authored colour comparison")
	var renderer:String=RenderingServer.get_current_rendering_method();var suffix:String=("_baseline_" if baseline else "_")+renderer
	var passed:bool=failures.is_empty() and wrong_detected==8
	var result:Dictionary={"actual_render":true,"renderer":renderer,"passed":passed,"baseline_reproduction":baseline,"failures":failures,"records":records,"legacy_defects_detected":legacy_detected,"wrong_space_controls_detected":wrong_detected,"source_sha256":hashes,"scope":"Unshaded production terrain/structure colour expressions against source_color swatches, using actual mesh COLOR values. Does not validate complete Forward+ scenes or grant artistic sign-off."}
	image.save_png("res://tools/biome_extensions/artifacts/check_authored_color_space"+suffix+".png")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_authored_color_space"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("EXTENSION_AUTHORED_COLOR ",renderer," baseline=",baseline," failures=",failures," negative controls=",wrong_detected)
	scene.queue_free();await process_frame;quit(0 if (legacy_detected==8 and wrong_detected==8 if baseline else passed) else 1)
