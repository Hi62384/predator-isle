extends SceneTree
const IDS=["Grass001","Ground054","Snow001","Rock030","Ground037","Ground048","Gravel020","Rock035","Rock028"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var material: ShaderMaterial=load("res://materials/terrain.tres")
	var palette: Texture2DArray=material.get_shader_parameter("palette_color")
	assert(palette.get_layers()==IDS.size())
	var normal_palette: Texture2DArray=material.get_shader_parameter("palette_normal")
	assert(normal_palette.get_layers()==IDS.size())
	print("PALETTE bound=",palette," layers=",palette.get_layers())
	for i in range(IDS.size()):
		var source: Image=load("res://materials/palette_color_"+IDS[i]+".res")
		print("layer ",i," format=",source.get_format()," size=",source.get_size()," mips=",source.get_mipmap_count())
		assert(source.get_format()==Image.FORMAT_DXT5 and source.get_size()==Vector2i(2048,2048) and source.get_mipmap_count()==11)
		source=source.duplicate()
		source.decompress()
		source.clear_mipmaps()
		source.resize(1,1,Image.INTERPOLATE_LANCZOS)
		print("average ",source.get_pixel(0,0))
		var id: String=IDS[i]
		var compressed: Image=load("res://materials/palette_normal_"+id+".res")
		assert(compressed.get_format()==Image.FORMAT_RGTC_RG and compressed.get_size()==Vector2i(1024,1024) and compressed.get_mipmap_count()==10)
		compressed=compressed.duplicate()
		assert(compressed.decompress()==OK)
		var original:=Image.load_from_file("res://assets/textures/ambientcg/"+id+"/"+id+"_2K-JPG_NormalGL.jpg")
		original.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
		var error:=0.0
		for y in range(16,1024,32):
			for x in range(16,1024,32):
				var a:=normal_from_rg(original.get_pixel(x,y))
				var b:=normal_from_rg(compressed.get_pixel(x,y))
				error+=rad_to_deg(acos(clampf(a.dot(b),-1,1)))
		error/=1024.0
		print("BC5 decoded angular error mean degrees ",id,": ",error)
		assert(is_finite(error) and error<10.0,"Excessive compressed normal error")
	var rect:=ColorRect.new()
	rect.size=Vector2(1280,500)
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2DArray palette : source_color, filter_linear_mipmap; void fragment(){ COLOR=vec4(texture(palette,vec3(fract(UV*vec2(9.0,1.0)),floor(UV.x*9.0))).rgb,1.0); }"
	var m:=ShaderMaterial.new()
	m.shader=shader
	m.set_shader_parameter("palette",palette)
	rect.material=m
	root.add_child(rect)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/palette_swatches.png")
	quit()

func normal_from_rg(color: Color) -> Vector3:
	var xy:=Vector2(color.r,color.g)*2.0-Vector2.ONE
	return Vector3(xy.x,xy.y,sqrt(maxf(1.0-xy.length_squared(),0.001))).normalized()
