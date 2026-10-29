extends SceneTree
func _initialize()->void:
	var path:String="res://tools/badlands/artifacts/check_fan_gradient_candidate.json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(not report.passed and not report.failures.is_empty())
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source])
	report.source_sha256[path]=FileAccess.get_sha256(path);report.source_sha256["res://tools/badlands/record_fan_gradient_failure.gd"]=FileAccess.get_sha256("res://tools/badlands/record_fan_gradient_failure.gd")
	report["failure_context"]="Private graded-apron prototype passed zero-mode and finite-height controls,but12 nonheight-control comparisons failed. Preserve before adding more detailed diagnostics;not production adoption."
	FileAccess.open("res://tools/biome_extensions/artifacts/fan_gradient_candidate_failure.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit()
