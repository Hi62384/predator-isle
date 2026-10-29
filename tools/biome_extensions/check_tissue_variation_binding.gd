extends "res://tools/biome_extensions/profile_tissue_flow_runtime.gd"
var checks:int=0
func verify(ok:bool,label:String)->void:checks+=1;assert(ok,label)
func run()->void:
	var source:String="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json";var fixture=JSON.parse_string(FileAccess.get_file_as_string(source));assert(fixture.passed)
	var selected:Dictionary={}
	for view:Dictionary in fixture.views:
		if view.seed==73921 and view.view=="ground":selected=view;break
	assert(not selected.is_empty());var focus:Vector3=vector(selected.focus);var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(73921,true)
	var original:Dictionary={};var original_maps:Dictionary={};var records:Array=[]
	for enabled:bool in [false,true]:
		scene=load("res://scenes/main.tscn").instantiate();terrain=scene.get_node("Terrain");camera=scene.get_node("FreeCamera");camera.set_script(null);terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.nerve_material_variation=enabled;terrain.world_seed=73921;terrain.maximum_lod=0;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
		for property:Dictionary in terrain.get_property_list():
			if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
		var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);verify(await settle(),"Actual controller cut committed with configured variation state")
		for material:ShaderMaterial in terrain._material_variants():verify(material.get_shader_parameter("alien_tissue_variation_enabled")==enabled,"Every actual terrain clone gets configured true/false,not shader default")
		for material:ShaderMaterial in terrain._structure_material_variants():
			if material.get_shader_parameter("family")==7:verify(material.get_shader_parameter("alien_tissue_variation_enabled")==enabled,"Actual Alien shell variants get independent configured true/false")
		# The real partition always retains a3x3 root neighbourhood,evenLOD0.
		# Inspect ALL nine roots rather than assuming a nonexistent one-root mode.
		verify(terrain._active_chunks.size()==9,"Actual bounded LOD0 nine-root binding fixture")
		var arrays:Dictionary={};var maps:Dictionary={};var vertices:int=0;var map_bytes:int=0
		for key:Vector3i in terrain._active_chunks:
			var node:MeshInstance3D=terrain._active_chunks[key];arrays[str(key)]=var_to_bytes(node.mesh.surface_get_arrays(0));vertices+=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			if node.mesh.has_meta("alien_tissue_flow"):
				var texture:ImageTexture=node.mesh.get_meta("alien_tissue_flow");var bytes:PackedByteArray=texture.get_image().get_data();maps[str(key)]=bytes;map_bytes+=bytes.size()
		verify(not maps.is_empty(),"Variation off retains actual flow maps")
		if not enabled:original=arrays;original_maps=maps
		else:verify(arrays==original and maps==original_maps,"Independent true/false changes neither complete terrain cut nor committed GPU maps")
		records.append({"variation_enabled":enabled,"leaves":9,"vertices":vertices,"flow_map_bytes":map_bytes});scene.queue_free();await process_frame;await process_frame
	var guards:Dictionary={source:FileAccess.get_sha256(source)}
	for path:String in fixture.source_sha256:assert(FileAccess.get_sha256(path)==fixture.source_sha256[path]);guards[path]=fixture.source_sha256[path]
	guards["res://tools/biome_extensions/check_tissue_variation_binding.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_tissue_variation_binding.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_variation_binding.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"checks":checks,"cases":records,"scope":"Two actual cold controller instances,configured variation false/true,boundedLOD0 actual nine-root cut at original seed73921 ground site. All configured terrain and Alien-shell variants inherit actual saved Resource setting;complete terrain cut and GPU path-map bytes exact. Initial one-root assumption failed and its distinct log remains,not acceptance. No GPU scenic/traversal/timing claim."},"  "));print("TISSUE_VARIATION_BINDING ",checks);quit()
