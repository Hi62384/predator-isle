extends "res://tools/blobs/render_blob_v2_sheets.gd"
func _run() -> void:
	var studies: Array[Dictionary]=[]
	var metrics: Array=[]
	for i in 2:
		var started:=Time.get_ticks_msec()
		var options: Dictionary={"profile":"mimic" if i==0 else "smooth_mimic","body_plan":"lopsided" if i==0 else "compact","faces":1.2,"sacs":.25,"lattice":.5,"tentacles":.5,"membranes":.5,"limbs":.2}
		var data: Dictionary=Cache.build(8800+i,2,"drag",7,null,options)
		var request_ms:=Time.get_ticks_msec()-started
		metrics.append({"seed":8800+i,"quality":2,"request_ms":request_ms,"cache_hit":data.get("cache_hit",false),"generation_ms":null if data.get("cache_hit",false) else request_ms,"statistics":data.statistics})
		studies.append(data)
		print("BLOB_HIGH_QUALITY ",8800+i," triangles=",data.statistics.triangles)
	await _sheet(studies,2,Vector2i(900,900),"high_quality_faces.png",false)
	var file:=FileAccess.open(OUTPUT.path_join("high_quality_validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	quit()
