extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/profile_tissue_flow_runtime.gd")
	code=code.replace("render_alien_tissue_flow.json","render_tissue_variation_registered.json").replace("view.phase==1","true")
	assert(code.count('"alien_tissue_flow_enabled"')==2);code=code.replace('"alien_tissue_flow_enabled"','"alien_tissue_variation_enabled"')
	var marker:String="var samples:Array=[]";assert(code.count(marker)==1);code=code.replace(marker,'hashes["res://tools/biome_extensions/profile_tissue_variation_registered.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/profile_tissue_variation_registered.gd")\n\t'+marker)
	code=code.replace('"enabled":enabled','"variation_enabled":enabled').replace("profile_tissue_flow_runtime.json","profile_tissue_variation_registered.json")
	code=code.replace('"scope":"One actual committed','"scope":"REGISTERED variation uniform-only off/on/on/off twice per view;path flow remains ENABLED and maps resident throughout. Actual original single lookup versus registered varied lookup branch in the SAME production shader,not shader replacement. This supersedes the inherited flow-off/on description below. One actual committed')
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
