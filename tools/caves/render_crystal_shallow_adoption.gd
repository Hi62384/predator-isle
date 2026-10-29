extends "res://tools/caves/render_crystal_shallow_candidate.gd"
const Adoption:String="res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_adoption.json"
func inspection_name()->String:return "crystal_shallow_adoption"
func selection_label()->String:return "Same original2070case first positive at ordinal336,through the actual production provider"
func inspection_control_scope()->String:return "Actual production shallow switch/normal18percent/5,20,50,80,100depth preferences/.65density unchanged. Observer hook only records the actual generated region;no private geography injection or probability override."
func additional_guards()->Dictionary:return {Adoption:FileAccess.get_sha256(Adoption),"res://tools/caves/render_crystal_shallow_candidate.gd":FileAccess.get_sha256("res://tools/caves/render_crystal_shallow_candidate.gd")}
func inspection_prepare_workload(work)->void:
	var previous:Callable=work.network.region_finalizer
	work.network.region_finalizer=func(region:Dictionary)->Dictionary:
		var actual:Dictionary=previous.call(region)
		if actual.id==inspection_site():proposal=actual
		return actual
func run()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(Adoption));check(report is Dictionary and report.get("passed",false),"Complete production shallow adoption report available")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	for path:String in report.source_sha256:check(FileAccess.get_sha256(path)==report.source_sha256[path],"Original production adoption source unchanged "+path)
	selection=report.first_positive;check(not selection.is_empty(),"Same first original normal positive retained")
	if not failures.is_empty():print("SHALLOW_PRODUCTION_NATIVE_PREFLIGHT ",failures);quit(1);return
	await render_selected()
