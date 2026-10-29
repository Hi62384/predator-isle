extends SceneTree
const REFERENCE="res://tools/biome_extensions/artifacts/revisions/experiment_render_alien_tissue_flow_fc1f200ac1af/sources/shaders/alien_tissue_flow.gdshaderinc.txt"
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/profile_tissue_flow_runtime.gd")
	var marker:String="var samples:Array=[]";assert(code.count(marker)==1)
	code=code.replace(marker,'var reference_code:String=FileAccess.get_file_as_string("'+REFERENCE+'");var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc");var production_code:String=include.get("code")\n\tfor path:String in ["'+REFERENCE+'","res://tools/biome_extensions/profile_tissue_sampler_reference.gd"]:hashes[path]=FileAccess.get_sha256(path)\n\t'+marker)
	var toggle:String="set_flow(enabled)";assert(code.count(toggle)==1)
	code=code.replace(toggle,'set_flow(true);include.set("code",production_code if enabled else reference_code);assert(include.get("code")== (production_code if enabled else reference_code))')
	code=code.replace('"enabled":enabled','"skip_empty_samples":enabled').replace("profile_tissue_flow_runtime.json","profile_tissue_sampler_reference.json")
	var end_marker:String="for path:String in hashes:assert";assert(code.count(end_marker)==1);code=code.replace(end_marker,'include.set("code",production_code)\n\t'+end_marker)
	code=code.replace('"scope":"One actual committed', '"scope":"MATCHED sampler-only comparison:flow is ENABLED in every block. Held frozen unconditional4-sample analytic helper versus current empty-group skipping,alternating reference/current/current/reference twice per view. Resource-only include changes,no project writes;source intervention already proven effective by the native wrong-UV control. This supersedes the ordinary feature-off/on description below for this report. One actual committed')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
