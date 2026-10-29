extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_ground_union_worker_walk.gd")
	var begin:int=code.find("\tfor enabled:bool in [false,true]:");var end:int=code.find("\tfor path:String in guards:",begin);assert(begin>0 and end>begin)
	var block:String=code.substr(begin,end-begin);var indented:String=""
	for line:String in block.split("\n"):
		if not line.is_empty():indented+="\t"+line+"\n"
	var prefix:String='''	var views_path:String="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json";var views=JSON.parse_string(FileAccess.get_file_as_string(views_path));assert(views.passed);guards[views_path]=FileAccess.get_sha256(views_path)
	for path:String in views.source_sha256:assert(FileAccess.get_sha256(path)==views.source_sha256[path]);guards[path]=views.source_sha256[path]
	guards["res://tools/biome_extensions/check_ground_union_worker_walk_domains.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_ground_union_worker_walk_domains.gd")
	for seed_id:int in [73921,17,92881]:
		var found:bool=false
		for view:Dictionary in views.views:
			if view.seed==seed_id and view.view=="ground":focus=v3(view.focus);p=Vector2(focus.x,focus.z);found=true;break
		assert(found);reference_heights=[]
'''
	code=code.substr(0,begin)+prefix+indented+code.substr(end)
	code=code.replace(".builder(17,true)",".builder(seed_id,true)").replace("terrain.world_seed=17","terrain.world_seed=seed_id").replace('records.append({"candidate_enabled":enabled','records.append({"seed":seed_id,"candidate_enabled":enabled')
	code=code.replace("check_ground_union_worker_walk.json","check_ground_union_worker_walk_domains.json")
	code=code.replace('"scope":"PRIVATE actual full worker-dispatch/collision trial','"scope":"ADDITIONAL three original frozen pure-Alien ground sites,73921/17/92881,six actual320m original/candidate returns. No world reroll or original seed17 replacement. PRIVATE actual full worker-dispatch/collision trial')
	code=code.replace("at EXACT seed17 ground-boundary cross-section","at each EXACT original frozen ground-view cross-section").replace("Two320m capsule returns","Six320m capsule returns").replace("all-seed/custom-scale/cave acceptance","arbitrary-seed/custom-scale/cave acceptance")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
