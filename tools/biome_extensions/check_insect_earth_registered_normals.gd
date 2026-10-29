extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_insect_earth_normal_controls.gd";var source:String=FileAccess.get_file_as_string(original)
	var guard:String='for path:String in input.source_sha256:assert(FileAccess.get_sha256(path)==input.source_sha256[path]);hashes[path]=input.source_sha256[path]';assert(source.count(guard)==1)
	source=source.replace(guard,'''var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/biome_extensions/check_insect_earth_registered_normals.gd","res://tools/biome_extensions/check_insect_earth_normal_controls.gd","res://tools/biome_extensions/render_insect_earth_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)''')
	source=source.replace('res://tools/biome_extensions/artifacts/render_insect_earth_candidate.json','res://tools/biome_extensions/artifacts/revisions/experiment_insect_earth_trial_6eec1813dcd5/sources/tools/biome_extensions/artifacts/render_insect_earth_candidate.json.txt')
	source=source.replace('var pairs:Array=material_pairs()','var pairs:Array=configured_pairs()').replace('insect_earth_normal_%s_%s.png','insect_earth_registered_normal_%s_%s.png').replace('check_insect_earth_normal_controls.json','check_insect_earth_registered_normals.json')
	source=source.replace("PRIVATE actual committed fullLOD6roots","REGISTERED actual committed fullLOD6roots").replace("No substitute mesh/lighting/normal scan or production registration.","Actual registered material and configured control;no substitute mesh/lighting/normal scan or full-art/cave certificate.")
	source+='''
func configured_pairs()->Array:
	var pairs:Array=[]
	verify(terrain._settings_snapshot.insect_colony.nest_earth_material,"Actual registered configured material enabled")
	for node:MeshInstance3D in terrain._active_chunks.values():
		if not node.mesh.has_meta("extension_structures"):continue
		var mesh:ArrayMesh=node.mesh.get_meta("extension_structures")
		for surface in range(mesh.get_surface_count()):
			var material:ShaderMaterial=mesh.surface_get_material(surface)
			if material.get_shader_parameter("family")!=6:continue
			verify(material.shader.resource_path=="res://shaders/insect_earth.gdshader","Actual original production material,not a test substitute")
			pairs.append({"mesh":mesh,"surface":surface,"candidate":material})
	return pairs
'''
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
