extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	preload("res://tools/biome_extensions/check_tissue_variation_registration.gd").verify_formula()
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_tissue_variation_candidate.gd")
	var old:String='var baseline:String=include.get("code");var candidate:String=CANDIDATE.source_for(baseline)';assert(code.count(old)==1)
	code=code.replace(old,'var baseline:String=FileAccess.get_file_as_string("'+preload("res://tools/biome_extensions/check_tissue_variation_registration.gd").ORIGINAL+'");var candidate:String=include.get("code")')
	# A preceding view ends on the frozen reference. Restore the registered
	# shader BEFORE creating the next controller and inspecting its bindings.
	var scene_marker:String='scene=load("res://scenes/main.tscn").instantiate()';assert(code.count(scene_marker)==1)
	code=code.replace(scene_marker,'include.set("code",candidate);'+scene_marker)
	var marker:String="var cuts:Array=[]";assert(code.count(marker)==1)
	code=code.replace(marker,'for path:String in ["res://tools/biome_extensions/render_tissue_variation_registered.gd","res://tools/biome_extensions/check_tissue_variation_registration.gd","'+preload("res://tools/biome_extensions/check_tissue_variation_registration.gd").ORIGINAL+'"]:hashes[path]=FileAccess.get_sha256(path)\n\t'+marker)
	marker="var cut:Dictionary={}";assert(code.count(marker)==1)
	code=code.replace(marker,'verify(terrain.settings.alien_infected.nerve_material_variation,"Actual world default is enabled")\n\t\tfor material:ShaderMaterial in terrain._material_variants():verify(material.get_shader_parameter("alien_tissue_variation_enabled")==true,"Configured terrain clones inherit material control")\n\t\tfor material:ShaderMaterial in terrain._structure_material_variants():\n\t\t\tif material.get_shader_parameter("family")==7:verify(material.get_shader_parameter("alien_tissue_variation_enabled")==true,"Configured active/staged/cached/shared Alien shells inherit material control")\n\t\t'+marker)
	code=code.replace("tissue_variation_%d_%s_","tissue_variation_registered_%d_%s_").replace("render_tissue_variation_candidate.json","render_tissue_variation_registered.json")
	code=code.replace('"scope":"Private Resource-only material variation','"scope":"REGISTERED actual configured nerve_material_variation=true bound to terrain and all Alien shell clones. Complete formula matched accepted private prototype. Frozen pre-variation original versus current false/current true/current false/frozen original same-scene controls. Actual material variation')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
