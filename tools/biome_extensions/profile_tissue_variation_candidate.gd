extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/profile_tissue_flow_runtime.gd")
	var marker:String="var samples:Array=[]";assert(code.count(marker)==1)
	code=code.replace(marker,'var include:Resource=load("res://shaders/alien_tissue_flow.gdshaderinc");var baseline:String=include.get("code");var candidate:String=preload("res://tools/biome_extensions/tissue_variation_candidate.gd").source_for(baseline)\n\tfor path:String in ["res://tools/biome_extensions/tissue_variation_candidate.gd","res://tools/biome_extensions/profile_tissue_variation_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)\n\t'+marker)
	assert(code.count("set_flow(enabled)")==1)
	code=code.replace("set_flow(enabled)",'set_flow(true);include.set("code",candidate if enabled else baseline);assert(include.get("code")== (candidate if enabled else baseline))')
	code=code.replace('"enabled":enabled','"variation_enabled":enabled').replace("profile_tissue_flow_runtime.json","profile_tissue_variation_candidate.json")
	var tail:String="for path:String in hashes:assert";assert(code.count(tail)==1);code=code.replace(tail,'include.set("code",baseline)\n\t'+tail)
	code=code.replace('"scope":"One actual committed','"scope":"PRIVATE matched two-sample/mirrored/continuous-strain variation comparison;flow ENABLED in every block. Same actual cut,original/candidate/candidate/original twice per view,analytic strain footprints. Resource-only shader intervention,unchanged production files.24 GPU timing blocks. This supersedes the inherited feature-off/on boilerplate below. One actual committed')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
