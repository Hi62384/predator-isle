extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	preload("res://tools/biome_extensions/check_tissue_variation_registration.gd").verify_formula()
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_alien_tissue_flow_gpu.gd")
	var marker:String="materials.append(material)";assert(code.count(marker)==1);code=code.replace(marker,marker+';material.set_shader_parameter("alien_tissue_variation_enabled",true)')
	marker="var shell:String=";assert(code.count(marker)==1);code=code.replace(marker,'for path:String in ["res://tools/biome_extensions/check_tissue_variation_projection_registered.gd","res://tools/biome_extensions/check_tissue_variation_registration.gd","res://tools/biome_extensions/tissue_variation_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)\n\t'+marker)
	code=code.replace("tissue_flow_gpu_%d_%d.png","tissue_variation_registered_projection_%d_%d.png").replace("check_alien_tissue_flow_gpu.json","check_tissue_variation_projection_registered.json")
	code=code.replace('"scope":"Actual production shared tissue helper','"scope":"REGISTERED variation explicitly enabled in all three panels. No shader override. Actual production shared tissue helper')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
