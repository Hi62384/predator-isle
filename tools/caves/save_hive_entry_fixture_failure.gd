extends SceneTree
func _initialize()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/save_hive_entry_fixture_failure.gd","res://tools/caves/check_hive_entry_material.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://.godot/extensions_check_cave_hive_entry_material.engine.log","res://.godot/extensions_check_cave_hive_entry_material.err.log"]:guards[path]=FileAccess.get_sha256(path)
	var report:Dictionary={"passed":false,"checks":1,"failures":["Native material fixture rejected custom0: RGB source was incorrectly declared RGBA. No material comparison accepted; production uploader already selects RGB/RGBA by actual stride."],"source_sha256":guards}
	FileAccess.open("res://tools/biome_extensions/artifacts/failed_hive_entry_fixture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit()
