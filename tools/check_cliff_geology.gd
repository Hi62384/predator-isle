extends SceneTree

func _initialize() -> void:
	var texture: Texture2D=load("res://materials/cliff_geology.res")
	assert(texture!=null)
	var data:=texture.get_image()
	assert(data.get_size()==Vector2i(1024,1024))
	assert(data.get_format()==Image.FORMAT_RGBAH)
	assert(data.has_mipmaps())
	var lo:=Vector4(1,1,1,1)
	var hi:=Vector4.ZERO
	var quiet:=0
	var count:=0
	for y in range(0,1024,8):
		for x in range(0,1024,8):
			var c:=data.get_pixel(x,y)
			count+=1
			if maxf(c.g,c.a)<0.08: quiet+=1
			for k in range(4):
				assert(is_finite(c[k]))
				lo[k]=minf(lo[k],c[k]);hi[k]=maxf(hi[k],c[k])
	for k in range(4): assert(hi[k]-lo[k]>0.1,"Empty geological channel")
	assert(float(quiet)/count>0.65,"Cliff detail no longer has enough clean space")
	var material: ShaderMaterial=load("res://materials/terrain.tres")
	assert(material.get_shader_parameter("cliff_geology")!=null)
	var slopes: Texture2D=material.get_shader_parameter("cliff_geology_slopes")
	assert(slopes!=null and slopes.get_image().get_format()==Image.FORMAT_RGH)
	var slope_data:=slopes.get_image()
	for y in range(0,1024,16):
		for x in range(0,1024,16):
			var c:=slope_data.get_pixel(x,y)
			assert(is_finite(c.r) and is_finite(c.g))
	print("PASS 1024 RGBAH mipmapped geology, four nonempty finite channels, saved material binding; bytes=",data.get_data_size())
	quit()
