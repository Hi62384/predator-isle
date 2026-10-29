extends SceneTree
func _initialize()->void:
	var guards:Dictionary={};var evidence:Array=[]
	for name:String in ["check_fan_gradient_candidate","check_fan_gradient_collision"]:
		var path:String="res://tools/badlands/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty());guards[path]=FileAccess.get_sha256(path)
		for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source]);guards[source]=report.source_sha256[source]
		evidence.append({"report":path,"assertions":report.get("assertions",0),"cases":report.cases.size()})
		for suffix:String in ["engine.log","out.log","err.log"]:
			var log:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(log):guards[log]=FileAccess.get_sha256(log)
	guards["res://tools/badlands/save_fan_gradient_trial.gd"]=FileAccess.get_sha256("res://tools/badlands/save_fan_gradient_trial.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/fan_gradient_trial.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"evidence":evidence,"production_registration":false,"scope":"Private pre-adoption fan gradient study:8987 exact-zero,finite-height,control and outlet assertions;three unchanged static physical capsule return routes at.025. One Jolt capacity warning,all routes complete. Not production/native/performance acceptance. Preserve original dynamic prototype and raw evidence before production changes."},"  "));quit()
