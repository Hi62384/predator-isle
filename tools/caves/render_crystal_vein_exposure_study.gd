extends "res://tools/caves/render_crystal_indexed_scene.gd"
func inspection_name()->String:return "crystal_vein_exposure_study"
func additional_guards()->Dictionary:
	var guards:Dictionary=super.additional_guards();var parent_path:String="res://tools/caves/render_crystal_indexed_scene.gd";guards[parent_path]=FileAccess.get_sha256(parent_path);return guards
func run()->void:
	target_key="family_2";await super.run()
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var original_include:String=FileAccess.get_file_as_string("res://shaders/cave_crystal_surface.gdshaderinc");var old_return:String="float width=max(fwidth(a),fwidth(b));return 1.0-smoothstep(.035,.09+width,min(abs(a),abs(b)));";var new_return:String="float width=max(fwidth(a),fwidth(b));float patch=.5+.5*sin(p.x*(6.283185307179586/48.0)+.7*sin(p.z*(6.283185307179586/32.0)))*sin(p.z*(6.283185307179586/60.0)-p.y*(6.283185307179586/48.0));float exposure=smoothstep(.60,.82,patch);return (1.0-smoothstep(.035,.09+width,min(abs(a),abs(b))))*exposure;";check(original_include.contains(old_return),"Exact preselected original host-vein expression available");var candidate_include:String=original_include.replace(old_return,new_return);var originals:Dictionary={};var candidates:Dictionary={};var meshes:Dictionary={}
	for node:MeshInstance3D in nodes:
		if node.mesh==null:continue
		var original:ShaderMaterial=node.mesh.surface_get_material(0);var code:String=original.shader.code
		if not code.contains("#include \"res://shaders/cave_crystal_surface.gdshaderinc\""):continue
		originals[node]=original;meshes[node]=node.mesh
		if not candidates.has(original):
			var material:ShaderMaterial=original.duplicate();var shader:=Shader.new();shader.code=code.replace("#include \"res://shaders/cave_crystal_surface.gdshaderinc\"",candidate_include);material.shader=shader;candidates[original]=material
	check(not originals.is_empty(),"Actual generated host material found,not a substitute flat diagnostic shader")
	var direction:Vector3=(data.room.point-data.parent.point).normalized();camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(data.room.point+direction*data.room.chamber_radius*.8+Vector3.UP*data.room.chamber_height*.4);light.position=camera.position+Vector3.UP*.5;light.visible=true;var original:Image=await crystal_picture("host_bands_original")
	for node:MeshInstance3D in originals:node.material_override=candidates[originals[node]]
	var candidate:Image=await crystal_picture("host_bands_local_exposures")
	for node:MeshInstance3D in originals:node.material_override=null;check(node.mesh==meshes[node],"Original complete native mesh object retained throughout shader-only study")
	var restored:Image=await crystal_picture("host_bands_original_return");check(original.get_data()!=candidate.get_data(),"Bounded global physical exposure mask visibly changes real host veins");check(original.get_data()==restored.get_data(),"Exact original native scene restoration after private shader-only candidate")
	return {"private_candidate_not_adopted":true,"materials":candidates.size(),"native_meshes":meshes.size(),"candidate_source_sha256":candidate_include.sha256_text(),"visible_change":original.get_data()!=candidate.get_data(),"exact_original_return":original.get_data()==restored.get_data(),"candidate_expression":new_return,"scope":"FIRST indexed selenite chamber,original cave geometry/crystal batches/native colliders/settings/lighting;only host vein exposure shading changed in memory. No new textures/lights/world samples or vein contour displacement. Existing physical vein fragments remain unchanged. Not production adoption/reference-art/FPS/all-user completion."}
