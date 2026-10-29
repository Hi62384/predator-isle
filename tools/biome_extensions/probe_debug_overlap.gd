extends "res://tools/biome_extensions/probe_conduit_join.gd"
func run()->void:
	output_basename="probe_debug_overlap";capture_label="debug_overlap_probe"
	additional_guards=["res://tools/biome_extensions/probe_debug_overlap.gd","res://tools/biome_extensions/artifacts/probe_debug_physical_pixels.json"]
	var diagnostic=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/probe_debug_physical_pixels.json"));assert(diagnostic.passed)
	probe_pixels.clear()
	for item:Dictionary in diagnostic.cases[0].mismatched_pixels:probe_pixels.append(Vector2(item.pixel[0],item.pixel[1]))
	assert(probe_pixels.size()==4,"Exact four-pixel failure coordinates, not a newly chosen exclusion mask")
	await super.run()
