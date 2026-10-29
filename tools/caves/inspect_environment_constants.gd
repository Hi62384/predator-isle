extends SceneTree
func _initialize()->void:
	for name:String in ClassDB.class_get_integer_constant_list("Environment"):
		if name.contains("AMBIENT") or name.contains("REFLECT"):print(name,"=",ClassDB.class_get_integer_constant("Environment",name))
	for property:Dictionary in Environment.new().get_property_list():
		if str(property.name).contains("ambient_light_source") or str(property.name).contains("reflected_light_source"):print(property)
	quit()
