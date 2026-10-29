extends SceneTree
var guards:Dictionary={}
func checked(path:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.get("passed",report.get("completed",false)) and report.failures.is_empty());guards[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale fan evidence "+source);guards[source]=report.source_sha256[source]
	return report
func _initialize()->void:
	var numeric:=checked("res://tools/badlands/artifacts/check_fan_gradient.json");assert(numeric.assertions==19965)
	checked("res://tools/badlands/artifacts/check_fan_geometry.json")
	var native:=checked("res://tools/badlands/artifacts/render_fan_gradient.json");assert(native.views.size()==18 and native.phases.size()==9)
	var aprons:=checked("res://tools/badlands/artifacts/check_fan_apron_collision.json")
	var accelerated:=checked("res://tools/badlands/artifacts/check_streamed_wash.json")
	var realtime:=checked("res://tools/badlands/artifacts/check_realtime_streamed_wash.json")
	var cost:=checked("res://tools/badlands/artifacts/profile_fan_gradient.json")
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	for name:String in ["check_fan_gradient","gradient_check_fan_geometry","render_fan_gradient","gradient_check_fan_apron_collision","gradient_check_streamed_wash","profile_fan_gradient_fixed","check_realtime_streamed_wash"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/badlands/save_fan_gradient_adoption.gd","res://data/surface_regression_20261018.json"]:guards[path]=FileAccess.get_sha256(path)
	for path:String in native.capture_sha256:assert(FileAccess.get_sha256(path)==native.capture_sha256[path])
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"all_user_tasks_complete":false,"source_sha256":guards,"capture_sha256":native.capture_sha256,"completed_utc":Time.get_datetime_string_from_system(true),"assertions":numeric.assertions,"static_apron_returns":aprons.cases,"accelerated_streamed_wash":accelerated,"realtime_streamed_wash":realtime,"cost":cost,"resource_observations_transcribed":{"native_sampled_mib":1183.5,"native_limit_mib":2048,"apron_sampled_mib":111.7,"accelerated_wash_sampled_mib":546.4,"physics_limit_mib":1024,"sample_period_ms":500,"isolated":false},"scope":"Registered default.025m/m longitudinal fan deposits follow their finite actual feeder frames,weighted overlap and primary/feeder floor protection. Independent fan_gradient=0 preserves the complete pre-gradient terrain/water/packed payload.19965 checks against frozen original/private prototype,five gradients/three seeds/nine logical fans,18 real native zero/graded/zero views with complete cut reference return,three static capsule returns,existing accelerated2.74km wash and a separately declared unpaused real-time2.74km production return pass.31 shared regressions pass. Nine alternating near128 cold-builder pairs record sampling cost,not an isolated speedup. Native views show modest apron change;remaining surface reference art and ordered cave systems are not complete. Jolt capacity warning is retained wherever present in raw logs,not fixed or silently suppressed."}
	for path:String in ["res://data/badlands_fan_gradient_adoption.json","res://tools/biome_extensions/artifacts/badlands_fan_gradient_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FAN_GRADIENT_ADOPTED ",guards.size()," guards /18 images /real-time seconds=",realtime.walk_wall_seconds);quit()
