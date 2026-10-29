extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_conduit_shoulder_candidate.gd")
	code=code.replace('const Candidate=preload("res://tools/biome_extensions/conduit_shoulder_candidate.gd")','const Candidate=preload("res://tools/biome_extensions/conduit_ground_union_candidate.gd")')
	var marker:String="var focus:Vector3=";assert(code.count(marker)==1)
	code=code.replace(marker,'for path:String in ["res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/check_conduit_ground_union_candidate.gd","res://tools/biome_extensions/render_conduit_ground_union_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)\n\t'+marker)
	code=code.replace("shoulder_candidate_","ground_union_candidate_").replace("render_conduit_shoulder_candidate.json","render_conduit_ground_union_candidate.json")
	code=code.replace('"scope":"PRIVATE actual seed17','"scope":"PRIVATE second ground-guided tangent-shoulder prototype,not the preserved first quartic-only trial. Actual seed17')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
