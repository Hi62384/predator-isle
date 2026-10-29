extends SceneTree
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/crystal_features.gd","res://scripts/caves/feature_renderer.gd","res://tools/caves/render_crystal_features.gd","res://.godot/extensions_render_cave_crystal_features.engine.log","res://.godot/extensions_render_cave_crystal_features.err.log"]:guards[path]=FileAccess.get_sha256(path)
	var log:String=FileAccess.get_file_as_string("res://.godot/extensions_render_cave_crystal_features.engine.log");assert(log.contains("index_count >= (uint32_t)index_array_len"))
	FileAccess.open("res://tools/biome_extensions/artifacts/crystal_native_lod_failure.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["Native GPU renderer rejects LOD index array equal in length to the full-detail surface;headless numeric/native-physics fixture did not exercise this renderer check."],"source_sha256":guards,"scope":"Original native render failure,not a pass. No numeric/gate relaxation;production must omit redundant non-reducing LOD levels and re-run same six first-positive family fixtures."},"  "));quit()
