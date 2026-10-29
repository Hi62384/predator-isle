extends RefCounted
## Adapt old live-resource references only when compiling an immutable source
## snapshot. The archived bytes and recorded source hashes remain untouched.
static func remap_source(source:String)->String:
	var paths=JSON.parse_string(FileAccess.get_file_as_string("res://config/resource_path_migration.json"))
	assert(paths is Dictionary)
	for original:String in paths:source=source.replace("res://"+original,"res://"+str(paths[original]))
	return source
static func configuration_files()->Array[String]:
	var result:Array[String]=[];var pending:Array[String]=["res://config"]
	while not pending.is_empty():
		var folder:String=pending.pop_back()
		for name:String in DirAccess.get_directories_at(folder):pending.append(folder.path_join(name))
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".tres"):result.append(folder.path_join(name))
	result.sort();return result
static func load_snapshot(path:String)->GDScript:
	var script:=GDScript.new()
	script.source_code=remap_source(FileAccess.get_file_as_string(path))
	var error:int=script.reload()
	assert(error==OK,"Could not compile historical snapshot: "+path)
	return script
