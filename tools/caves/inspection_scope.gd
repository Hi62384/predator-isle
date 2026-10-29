extends RefCounted
## Scope ONLY numeric cave surveys and preloaded mineral inspection fixtures.
## Full production return and global regression harnesses stay unchanged.
static func is_dependency(path:String)->bool:
	return not (path.begins_with("res://shaders/") and path.get_file().begins_with("blob_"))
static func capture_terrain_dependencies(guards:Dictionary)->void:
	# The canonical sampler is a dependency even when no outdoor mesh is
	# instantiated. Include every root terrain script and editable resource.
	for name:String in DirAccess.get_files_at("res://scripts"):
		if name.ends_with(".gd"):var path:String="res://scripts/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in preload("res://tools/maintenance/resource_paths.gd").configuration_files():guards[path]=FileAccess.get_sha256(path)
	guards["res://project.godot"]=FileAccess.get_sha256("res://project.godot")
static func dependency_closure_valid(guards:Dictionary)->bool:
	for path:String in guards:
		if not (path.begins_with("res://scripts/") or path.begins_with("res://shaders/") or path=="res://scenes/main.tscn"):continue
		var source:String=FileAccess.get_file_as_string(path)
		if source.contains("res://shaders/blob_") or source.contains("#include \"blob_") or source.contains("#include \"./blob_"):return false
	return true
static func isolate_environment(scene:Node)->bool:
	# These fixtures already remove Terrain and drive their own camera/world.
	# Detach the unrelated workshop BEFORE _ready;never edit the user's scene.
	var workshop:Node=scene.get_node_or_null("BlobWorkshop")
	if workshop!=null:scene.remove_child(workshop);workshop.free()
	return scene.get_node_or_null("BlobWorkshop")==null
static func observations()->Dictionary:
	var result:Dictionary={}
	for name:String in DirAccess.get_files_at("res://shaders"):
		if not name.begins_with("blob_"):continue
		var path:String="res://shaders/"+name
		if FileAccess.file_exists(path):result[path]=FileAccess.get_sha256(path)
	return result
static func description()->String:
	return "Cave/terrain scripts,shaders,settings and used helpers remain hash-guarded. Unrelated blob_* character shaders are observations only;guarded cave/terrain/main shader text must NOT reference them. Numeric surveys instantiate no character. Preloaded mineral inspection fixtures detach BlobWorkshop before _ready while preserving original main sky/sun/fog/camera and actual generated cave geometry. This does not change the full production-return or global source-regression harnesses."
