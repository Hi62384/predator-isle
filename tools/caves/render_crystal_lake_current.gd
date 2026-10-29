extends "res://tools/caves/render_crystal_lake_chamber_native.gd"
func inspection_name()->String:return "crystal_lake_current"
func selection_label()->String:return "Same original first five-case bank-lake location,revalidated through current production with normal floor ridges ON"
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();result["res://tools/caves/render_crystal_lake_chamber_native.gd"]=FileAccess.get_sha256("res://tools/caves/render_crystal_lake_chamber_native.gd");return result
func inspection_material_checks(data:Dictionary,_nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:
	check(str(data.pool.id)=="9:-3:1:3:lobe:0:seepage" and absf(float(data.pool.radius)-8.89335003122687)<.000001,"Exact original retained lake identity/radius,not replacement water")
	check(load("res://config/caves/biomes/crystal_cave_definition.tres").feature_configuration.floor_ridges,"Actual production normal floor-ridge control enabled in lake compatibility fixture")
	return {"original_selection_report":SelectionReport,"original_selection_sha256":FileAccess.get_sha256(SelectionReport),"same_original_pool":true,"floor_ridges":true,"scope":"Current fixed-location validation. Original complete five-case bank mechanism report remains historical under original source hashes,not rebound;normal lake frequency.12 unchanged and explicitly diagnostic frequency1 only in native fixture."}
func run()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(SelectionReport));check(report is Dictionary and report.get("passed",false),"Original completed historical bank-lake report retained")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	selection=report.first_positive;check(selection.host=="crystal_wastes" and int(selection.seed)==17 and str(selection.pool_id)=="9:-3:1:3:lobe:0:seepage","Exact original pre-physics first bank-lake location retained")
	if not failures.is_empty():quit(1);return
	await render_selected()
