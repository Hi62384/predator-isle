extends SceneTree
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var settings:Resource=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	await preload("res://scripts/terrain_shader_preparation.gd").prepare(self,settings)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");root.add_child(scene);terrain.set_process(false)
	var camera:Camera3D=scene.get_node("FreeCamera");camera.set_process(false);scene.get_node("Interface").hide();scene.get_node("BlobWorkshop").hide()
	var node:=MeshInstance3D.new();scene.add_child(node)
	var b=Builder.new();b.settings=settings;b.world_seed=73921;b.chunk_size=2048
	var coordinate:=Vector2i(-7,3);node.position=Vector3(coordinate.x*2048,0,coordinate.y*2048)
	var focus:=Vector3(-13440,250,8000);camera.position=focus+Vector3(0,1100,2100);camera.look_at(focus);camera.near=2
	var captures:Dictionary={}
	for blend:float in [12.0,3.0]:
		b.settings.height_blend=blend;b._configure_noise();var arrays:Array=b.build(coordinate,128)
		var mesh:=ArrayMesh.new();var flags:int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT if arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*4 else Mesh.ARRAY_CUSTOM_RGB_FLOAT)<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		for channel:int in range(1,4):
			if arrays[Mesh.ARRAY_CUSTOM0+channel]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<[Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][channel-1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,terrain._terrain_material);node.mesh=mesh
		for frame in range(12):await process_frame
		await RenderingServer.frame_post_draw
		var path:String="res://tools/biome_extensions/artifacts/biome_transition_"+("before" if blend==12 else "gradual")+".png"
		assert(root.get_texture().get_image().save_png(path)==OK);captures[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/biome_transition_preview.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"seed":73921,"coordinate":str(coordinate),"resolution":128,"scope":"Same actual mountain boundary,mesh spacing,camera,materials and lighting;only height_blend12 versus3"},"  "))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;scene.queue_free();await process_frame;print("BIOME_TRANSITION_PREVIEW saved same-camera comparison");quit()
