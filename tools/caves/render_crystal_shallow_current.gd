extends "res://tools/caves/render_crystal_shallow_adoption.gd"
func inspection_name()->String:return "crystal_shallow_current"
func selection_label()->String:return "Exact historical first2070case shallow Crystal location,original ordinal336,revalidated through current production provider"
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards()
	for path:String in ["res://tools/caves/render_crystal_shallow_adoption.gd","res://tools/caves/render_crystal_shallow_candidate.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func run()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(Adoption));check(report is Dictionary and report.get("passed",false),"Original complete historical shallow adoption report retained")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	selection=report.first_positive;check(int(selection.ordinal)==336 and selection.host=="quarry" and int(selection.seed)==1002,"Same original pre-physics first location;no replacement")
	# Original catalogue remains historical under its own hashes. This is a
	# fresh fixed-location validation,not a whole-cohort source-hash rebind.
	if not failures.is_empty():quit(1);return
	await render_selected()
