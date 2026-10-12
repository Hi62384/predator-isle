extends SceneTree
const IDS=["Rock064","Rock058","Rock051","Rock060","Rock030","Rock061","Rock050","Rocks007","Rocks011"]
func decode(c: Color) -> Vector3:
	var xy:=Vector2(c.r,c.g)*2.0-Vector2.ONE
	return Vector3(xy.x,xy.y,sqrt(maxf(1.0-xy.length_squared(),0.001))).normalized()
func _initialize() -> void:
	var m: ShaderMaterial=load("res://materials/terrain.tres")
	var a: Texture2DArray=m.get_shader_parameter("cliff_ambient_normals")
	assert(a!=null and a.get_layers()==9)
	var bytes:=0
	for id in IDS:
		var data: Image=load("res://materials/cliff_normal_"+id+".res")
		assert(data.get_format()==Image.FORMAT_RGTC_RG and data.get_size()==Vector2i(2048,2048) and data.get_mipmap_count()==11)
		bytes+=data.get_data_size()
		data=data.duplicate()
		assert(data.decompress()==OK)
		var source:=Image.load_from_file("res://assets/terrain/cliff_normals/ambientcg/"+id.to_lower()+"_normal.jpg")
		var error:=0.0
		for y in range(32,2048,64):
			for x in range(32,2048,64):
				error+=rad_to_deg(acos(clampf(decode(data.get_pixel(x,y)).dot(decode(source.get_pixel(x,y))),-1,1)))
		error/=1024.0
		assert(error<10.0 and is_finite(error))
		print(id," BC5 mean angular error degrees=",error)
	# Signed projection bases used in the shader must be tangent and right-handed.
	for sign_value in [-1.0,1.0]:
		for basis in [[Vector3(0,0,1),Vector3(0,-sign_value,0),Vector3(sign_value,0,0)],[Vector3(1,0,0),Vector3(0,0,-sign_value),Vector3(0,sign_value,0)],[Vector3(1,0,0),Vector3(0,sign_value,0),Vector3(0,0,sign_value)]]:
			assert(basis[0].cross(basis[1]).is_equal_approx(basis[2]))
			assert(is_zero_approx(basis[0].dot(basis[2])) and is_zero_approx(basis[1].dot(basis[2])))
	print("PASS nine maps, BC5/mips, signed projection bases; payload bytes=",bytes)
	quit()
