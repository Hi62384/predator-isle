extends "res://tools/blobs/render_blob_v2_sheets.gd"
func _run() -> void:
	var options: Dictionary={"profile":"smooth_mimic","body_plan":"compact","faces":1.2,"sacs":.25,"lattice":.5,"tentacles":.5,"membranes":.5,"limbs":.2}
	var base: Dictionary=Cache.build(8801,2,"drag",7,null,options)
	var models: Array[Dictionary]=[]
	for diagnostic in ["baseline","standard","no_microdetail","no_lod"]:
		var data: Dictionary=base.duplicate(true)
		data["render_diagnostic"]=diagnostic
		data.dna.profile=diagnostic
		models.append(data)
	await _sheet(models,4,Vector2i(700,700),"shading_diagnostics.png",false)
	quit()
