extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/badlands/render_fan_aprons.gd")
	var marker:String="terrain.settings.badlands.fan_shape_strength=1 if phase==1 else 0"
	assert(code.count(marker)==1)
	code=code.replace(marker,"terrain.settings.badlands.fan_shape_strength=1;terrain.settings.badlands.fan_gradient=.025 if phase==1 else 0")
	code=code.replace("fan_apron_%d_%d_%s.png","fan_gradient_%d_%d_%s.png").replace("render_fan_aprons.json","render_fan_gradient.json")
	var guard:String='for path:String in [numeric_path,"res://data/surface_regression_20261018.json"'
	assert(code.count(guard)==1)
	code=code.replace(guard,'for path:String in ["res://tools/badlands/render_fan_gradient.gd",numeric_path,"res://data/surface_regression_20261018.json"')
	code=code.replace("original/shaped/original","ungraded/graded/ungraded").replace("Original/reference-return","Ungraded/reference-return")
	code=code.replace("Three frozen on-land fan-province roots,", "Registered .025 longitudinal sediment gradient versus independent zero mode. Three frozen on-land fan-province roots,")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK)
	FileAccess.open("res://tools/badlands/artifacts/fan_gradient_render_fixture.txt",FileAccess.WRITE).store_string(code)
	set_script(script);call_deferred("run")
