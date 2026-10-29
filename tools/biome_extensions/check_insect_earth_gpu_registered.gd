extends SceneTree
func _initialize()->void:
	var path:String="res://tools/biome_extensions/check_insect_earth_phase.gd";var source:String=FileAccess.get_file_as_string(path)
	source=source.replace("res://tools/biome_extensions/insect_earth_optics.gdshaderinc","res://shaders/insect_earth_optics.gdshaderinc").replace("res://tools/biome_extensions/insect_earth_candidate.gdshader","res://shaders/insect_earth.gdshader").replace("check_insect_earth_phase.gd","check_insect_earth_gpu_registered.gd").replace("check_insect_earth_phase.json","check_insect_earth_gpu_registered.json").replace("insect_earth_phase_gpu.png","insect_earth_registered_gpu.png")
	var marker:String='var viewport:=SubViewport.new();';assert(source.count(marker)==1);source=source.replace(marker,'guards["'+path+'"]=FileAccess.get_sha256("'+path+'");'+marker)
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
