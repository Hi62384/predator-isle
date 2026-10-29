extends SceneTree
const OLD="res://tools/biome_extensions/artifacts/revisions/experiment_render_alien_tissue_flow_fc1f200ac1af/sources/shaders/alien_tissue_flow.gdshaderinc.txt"
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var reference:String=FileAccess.get_file_as_string(OLD);assert(reference.contains("ux*grid_dx.x+uy*grid_dx.y") and not reference.contains("strength<=0.0)continue"))
	var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc");include.set("code",reference);set_meta("held_reference_include",include)
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_alien_tissue_flow_gpu.gd")
	code=code.replace("tissue_flow_gpu_%d_%d.png","tissue_flow_sample_reference_%d_%d.png").replace("check_alien_tissue_flow_gpu.json","tissue_flow_sample_reference.json")
	var marker:String="var shell:String=";assert(code.count(marker)==1)
	code=code.replace(marker,'for path:String in ["'+OLD+'","res://tools/biome_extensions/run_tissue_sample_reference.gd"]:guards[path]=FileAccess.get_sha256(path)\n\t'+marker)
	code=code.replace('"scope":"Actual production shared tissue helper', '"scope":"Explicit held Resource-only pre-skip reference helper from the preserved production revision,analytic footprints but unconditional4 group samples. No project file changed. Actual shared tissue helper')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
