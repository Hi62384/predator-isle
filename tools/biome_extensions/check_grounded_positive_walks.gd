extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var script:=GDScript.new();script.source_code=preload("res://tools/biome_extensions/registered_grounded_walks.gd").source_for(false,"res://tools/biome_extensions/check_grounded_positive_walks.gd");assert(script.reload()==OK);set_script(script);call_deferred("run")
