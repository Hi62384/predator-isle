extends SceneTree
func _initialize()->void:
	var source:String="res://tools/biome_extensions/artifacts/vertex_tissue_phase_resource_failure.json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(source));assert(not report.passed)
	for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path])
	for path:String in [source,"res://tools/biome_extensions/bind_vertex_phase_failure.gd","res://tools/biome_extensions/bootstrap_vertex_tissue_phase.gd","res://tools/biome_extensions/biological_vertex_phase_candidate.gd","res://tools/biome_extensions/artifacts/check_vertex_tissue_phase_math.json","res://tools/biome_extensions/artifacts/check_mirrored_tissue_projection_vertex_phase.json"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	report["scope"]+=" The actual early bootstrap and candidate generator, plus their passing scoped arithmetic and projection controls, are bound here as additional sources. Failed full-scene preparation is not a production correction."
	var output:String="res://tools/biome_extensions/artifacts/vertex_tissue_phase_bound_failure.json"
	assert(not FileAccess.file_exists(output))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit()
