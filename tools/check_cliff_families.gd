extends SceneTree

func _initialize() -> void:
	var material: ShaderMaterial=load("res://materials/terrain.tres")
	for name in ["cliff_families","cliff_family_slopes_a","cliff_family_slopes_b","cliff_landforms","cliff_landform_slopes"]:
		var tex: Texture2D=material.get_shader_parameter(name)
		assert(tex!=null)
		var data:=tex.get_image()
		assert(data.get_size()==Vector2i(512,512) and data.has_mipmaps())
		var channels:=2 if name.ends_with("_b") else 4
		var low:=Vector4(INF,INF,INF,INF)
		var high:=Vector4(-INF,-INF,-INF,-INF)
		for y in range(0,512,8):
			for x in range(0,512,8):
				var c:=data.get_pixel(x,y)
				for k in range(channels):
					assert(is_finite(c[k]))
					low[k]=minf(low[k],c[k]);high[k]=maxf(high[k],c[k])
		for k in range(channels): assert(high[k]-low[k]>0.01,"Empty family channel")
		print("PASS ",name," bytes=",data.get_data_size())
	quit()
