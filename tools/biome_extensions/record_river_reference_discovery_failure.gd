extends SceneTree
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/render_river_cache_reference.gd","res://tools/biome_extensions/check_river_cached_meshes.gd","res://tools/biome_extensions/uncached_river_builder_oracle.gd","res://tools/biome_extensions/uncached_river_mountain_oracle.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/mountain_sampler.gd","res://.godot/extensions_render_river_cache_reference.engine.log","res://.godot/extensions_render_river_cache_reference.out.log","res://.godot/extensions_render_river_cache_reference.err.log"]:guards[path]=FileAccess.get_sha256(path)
	var images:Dictionary={}
	for phase in range(3):
		for kind:String in ["valley","overview"]:
			var path:String="res://tools/biome_extensions/artifacts/river_cache_73921_%d_%s.png"%[phase,kind]
			assert(FileAccess.file_exists(path));images[path]=FileAccess.get_sha256(path)
	var error:String=FileAccess.get_file_as_string("res://.godot/extensions_render_river_cache_reference.err.log")
	assert(error.contains("Actual Mountain/Tropical overlap"))
	FileAccess.open("res://tools/biome_extensions/artifacts/river_reference_discovery_failure.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["Seed17 discovery did not find required dry Mountain/Tropical overlap in1200 proposals. Runner stopped;no complete report or three-seed acceptance."],"source_sha256":guards,"capture_sha256":images,"scope":"Failed initial native fixture discovery. Completed seed73921 phases are partial evidence only. Preserve before expanding discovery;not a terrain failure repair or tolerance change."},"  "));quit()
