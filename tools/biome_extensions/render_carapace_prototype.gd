extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://tools/biome_extensions/carapace_geometry_prototype.gd","res://tools/biome_extensions/render_carapace_prototype.gd","res://scripts/chunk_terrain.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var item:Dictionary=manifest.families.alien_infected.primary;var p:=Vector2(item.x,item.z)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain");terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
	var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);var axis:Vector2=(edges[1]-p).normalized()
	var g=preload("res://scripts/biome_extension_structures.gd").new();g.origin=Vector3(p.x,0,p.y);g._support_steps=g.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
	preload("res://tools/biome_extensions/carapace_geometry_prototype.gd").new().emit(g,terrain._sampler,p,axis,240,100,.7)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=g.vertices;arrays[Mesh.ARRAY_NORMAL]=g.normals;arrays[Mesh.ARRAY_COLOR]=g.colors;arrays[Mesh.ARRAY_TEX_UV]=g.uvs
	var prototype:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,terrain._extension_materials[2]);prototype.mesh=mesh;prototype.position=g.origin;scene.add_child(prototype)
	var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y))+40,p.y)
	await capture("carapace_prototype","medium",focus,Vector3(-600,260,-800))
	var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*480
	await capture("carapace_prototype","sunlit",focus,Vector3(horizontal.x,200,horizontal.y))
	await capture("carapace_prototype","ground",focus,Vector3(-210,-36,-280))
	var close_face:Dictionary={};var highest:float=-INF
	for i in range(0,g.vertices.size(),3):
		var normal:Vector3=g.normals[i];var center:Vector3=(g.vertices[i]+g.vertices[i+1]+g.vertices[i+2])/3+g.origin
		if normal.y>.2 and normal.y<.85 and center.y>highest:highest=center.y;close_face={"center":center,"normal":normal}
	assert(not close_face.is_empty());await capture("carapace_prototype","close",close_face.center,close_face.normal*12)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Prototype source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_carapace_prototype.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_admission_implemented":false,"triangles":g.vertices.size()/3,"captures":records,"source_sha256":hashes,"scope":"Unintegrated worker-style morphology prototype placed explicitly in a private real-terrain scene using the actual Alien material. Not production streaming/placement/collision or completion evidence."},"  "));print("CARAPACE_PROTOTYPE_DONE");scene.queue_free();await process_frame;quit()
