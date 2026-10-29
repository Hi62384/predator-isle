extends SceneTree
func _initialize()->void:
	var source_path:String="res://tools/biome_extensions/check_earth_crystal_selected_contacts.gd";var source:String=FileAccess.get_file_as_string(source_path)
	var frozen:String="res://tools/biome_extensions/artifacts/revisions/experiment_earth_crystal_trial_5000e91a1dfb/sources/tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json.txt"
	source=source.replace('res://tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json',frozen)
	var old_guard:String='\tfor path:String in input.source_sha256:assert(FileAccess.get_sha256(path)==input.source_sha256[path]);guards[path]=input.source_sha256[path]'
	assert(source.count(old_guard)==1)
	var current_guard:String='\tvar regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)\n\tfor raw:String in regression.source_sha256:\n\t\tvar path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]\n\tguards["res://tools/biome_extensions/check_crystal_selected_contacts.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_crystal_selected_contacts.gd")'
	source=source.replace(old_guard,current_guard)
	source=source.replace('for site:Dictionary in input.cases:', 'for site:Dictionary in input.cases:\n\t\tif int(site.family)!=5:continue')
	var old_candidate:String='var candidate=preload("res://tools/biome_extensions/grounded_earth_crystal_candidate.gd").script_for().new()';assert(source.count(old_candidate)==1)
	source=source.replace(old_candidate,'var candidate=Structures.new();candidate.crystal_grounded_roots=true')
	source=source.replace('records.size()==24','records.size()==12').replace('Six frozen roots at four declared viewer distances','Three frozen Crystal roots at four declared viewer distances')
	source=source.replace('res://tools/biome_extensions/artifacts/check_earth_crystal_selected_contacts.json','res://tools/biome_extensions/artifacts/check_crystal_selected_contacts.json')
	source=source.replace('"production_registration":false','"production_registration":true')
	source=source.replace('PRIVATE actual production partition+resolution policy','REGISTERED Crystal-only actual production geometry and partition+resolution policy').replace('Six preselected dry Crystal/Insect roots','Three ORIGINAL preselected dry Crystal roots')
	source=source.replace('No actual Jolt traversal or continuous-edge guarantee.','No actual Jolt traversal or continuous-edge guarantee. New configuration is independently checked by complete-build registration;this test sets the real primitive member directly. No private candidate constructor or regenerated source.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
