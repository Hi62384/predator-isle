extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc")
	include.set("code",preload("res://tools/biome_extensions/tissue_variation_candidate.gd").source_for(include.get("code")));set_meta("held_variation_projection_include",include)
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_alien_tissue_flow_gpu.gd")
	var marker:String="var shell:String=";assert(code.count(marker)==1)
	code=code.replace(marker,'for path:String in ["res://tools/biome_extensions/tissue_variation_candidate.gd","res://tools/biome_extensions/check_tissue_variation_projection.gd"]:guards[path]=FileAccess.get_sha256(path)\n\t'+marker)
	code=code.replace("tissue_flow_gpu_%d_%d.png","tissue_variation_projection_%d_%d.png").replace("check_alien_tissue_flow_gpu.json","check_tissue_variation_projection.json")
	code=code.replace('"scope":"Actual production shared tissue helper','"scope":"Private held Resource-only variation helper;all production files unchanged. Actual shared tissue helper')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
