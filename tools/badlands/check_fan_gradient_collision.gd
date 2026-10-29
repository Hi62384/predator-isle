extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var original:String=FileAccess.get_file_as_string("res://tools/badlands/check_fan_apron_collision.gd")
	var builder:String='preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id)'
	assert(original.count(builder)==1)
	var code:String=original.replace(builder,'preload("res://tools/badlands/fan_gradient_candidate.gd").builder(seed_id,.025)').replace("res://tools/badlands/artifacts/check_fan_apron_collision.json","res://tools/badlands/artifacts/check_fan_gradient_collision.json")
	var guard:String='for path:String in ["res://tools/badlands/check_fan_apron_collision.gd"'
	assert(code.count(guard)==1)
	code=code.replace(guard,'for path:String in ["res://tools/badlands/check_fan_gradient_collision.gd","res://tools/badlands/fan_gradient_candidate.gd","res://tools/badlands/check_fan_apron_collision.gd"')
	code=code.replace('"scope":"Three fixed on-land fan-province root frames.', '"scope":"PRIVATE .025 longitudinal fan deposit study using the unchanged production physical fixture. Three fixed on-land fan-province root frames.')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK)
	FileAccess.open("res://tools/badlands/artifacts/fan_gradient_collision_fixture.txt",FileAccess.WRITE).store_string(code)
	# SceneTree scripts cannot be attached to the running tree. Transfer the
	# generated run method to this same SceneTree before its deferred call.
	set_script(script);call_deferred("run")
