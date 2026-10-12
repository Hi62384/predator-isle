extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,0),Vector3(0,1,0),Vector3(1,-1,0)])
	arrays[Mesh.ARRAY_CUSTOM0]=PackedFloat32Array([1,0,0,0,1,0,0,0,1])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	assert(mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]==arrays[Mesh.ARRAY_CUSTOM0])
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled; varying vec3 controls; void vertex(){controls=CUSTOM0.xyz;} void fragment(){ALBEDO=controls;}"
	var material:=ShaderMaterial.new();material.shader=shader
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;root.add_child(node)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,3);root.add_child(camera)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.resize(480,240)
	var maximum:=Vector3.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c:=image.get_pixel(x,y)
			maximum=Vector3(maxf(maximum.x,c.r),maxf(maximum.y,c.g),maxf(maximum.z,c.b))
	assert(maximum.x>0.8 and maximum.y>0.8 and maximum.z>0.8,"GPU lost a geology channel")
	image.save_png("res://tools/geology_binding.png")
	print("CUSTOM0 format=",mesh.surface_get_format(0)," CPU roundtrip and GPU RGB coverage PASS ",maximum)
	quit()
