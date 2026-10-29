extends SceneTree
func _initialize()->void:
	for property:Dictionary in ProjectSettings.get_property_list():
		var name:String=property.name
		if name.contains("shader") or (name.contains("thread") and name.begins_with("rendering/")):print(name," = ",ProjectSettings.get_setting(name))
	quit()
