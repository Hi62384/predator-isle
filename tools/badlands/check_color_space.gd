extends SceneTree
## Compare the actual production colour helper with source_color textures.
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_size(Vector2i(512,512));root.size=Vector2i(512,512)
	var source:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	var expression:=RegEx.new();assert(expression.compile("vec3 badlands_working_color\\(vec3 srgb\\)\\{[\\s\\S]*?\\n\\}")==OK)
	var found:RegExMatch=expression.search(source);assert(found!=null,"Production colour function found")
	var colors:Array[Color]=[Color(.48,.31,.24),Color(.65,.56,.44),Color(.63,.56,.49),Color(.55,.43,.29),Color(.34,.33,.36),Color(.4,.42,.46),Color(.65,.61,.53),Color(.025,.035,.045)]
	var pixels:=Image.create_empty(1,colors.size(),false,Image.FORMAT_RGB8);var authored:=PackedVector3Array()
	for index in range(colors.size()):
		pixels.set_pixel(0,index,colors[index]);var c:Color=pixels.get_pixel(0,index);authored.append(Vector3(c.r,c.g,c.b))
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,fog_disabled;uniform sampler2D reference:source_color,filter_nearest,repeat_disable;uniform vec3 authored[8];\n"+found.get_string()+"\nvoid fragment(){int row=clamp(int(UV.y*8.0),0,7);vec3 target=texture(reference,vec2(.5,UV.y)).rgb;vec3 result=badlands_working_color(authored[row]);vec3 old=pow(authored[row],vec3(2.2));vec3 wrong=OUTPUT_IS_SRGB?old:authored[row];ALBEDO=UV.x<.25?target:(UV.x<.5?result:(UV.x<.75?old:wrong));}\n"
	var scene:=Node3D.new();root.add_child(scene)
	var quad:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(8,8);quad.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("reference",ImageTexture.create_from_image(pixels));material.set_shader_parameter("authored",authored);quad.material_override=material;scene.add_child(quad)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,2);camera.current=true;scene.add_child(camera)
	for frame in range(15):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var failures:Array=[];var negatives:int=0;var maximum_error:float=0;var records:Array=[]
	for row in range(8):
		var y:int=int((row+.5)*image.get_height()/8)
		var reference:Color=image.get_pixel(image.get_width()/8,y);var actual:Color=image.get_pixel(image.get_width()*3/8,y);var old:Color=image.get_pixel(image.get_width()*5/8,y);var wrong:Color=image.get_pixel(image.get_width()*7/8,y)
		var error:float=maxf(absf(reference.r-actual.r),maxf(absf(reference.g-actual.g),absf(reference.b-actual.b)))
		var old_error:float=maxf(absf(reference.r-old.r),maxf(absf(reference.g-old.g),absf(reference.b-old.b)))
		var wrong_error:float=maxf(absf(reference.r-wrong.r),maxf(absf(reference.g-wrong.g),absf(reference.b-wrong.b)))
		maximum_error=maxf(maximum_error,error)
		if error>2.0/255:failures.append(row)
		if wrong_error>.015:negatives+=1
		records.append({"row":row,"reference":reference,"actual":actual,"error":error,"unconditional_pow_2_2_error":old_error,"wrong_working_space_error":wrong_error})
	var renderer:String=RenderingServer.get_current_rendering_method()
	var report:Dictionary={"actual_render":true,"renderer":renderer,"adapter":RenderingServer.get_video_adapter_name(),"positive_cases":8,"negative_cases_detected":negatives,"maximum_rgb_error":maximum_error,"failures":failures,"records":records,"shader_sha256":FileAccess.get_sha256("res://shaders/badlands_material.gdshaderinc"),"scope":"Production authored-colour helper versus source_color textures. Wrong-working-space negative control is renderer-aware; unconditional old pow(2.2) is measured separately. This does not validate the whole terrain in Forward+."}
	image.save_png("res://tools/badlands/artifacts/check_color_space_"+renderer+".png")
	FileAccess.open("res://tools/badlands/artifacts/check_color_space_"+renderer+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_COLOR_SPACE ",report)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() and negatives>=7 else 1)
