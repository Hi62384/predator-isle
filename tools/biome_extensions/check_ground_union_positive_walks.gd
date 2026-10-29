extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_ground_union_worker_walk_domains.gd")
	var sites:String="for seed_id:int in [73921,17,92881]:";assert(code.count(sites)==1);code=code.replace(sites,"for seed_id:int in [73921,17]:")
	code=code.replace("check_ground_union_worker_walk_domains.json","check_ground_union_positive_walks.json")
	code=code.replace("ADDITIONAL three original frozen pure-Alien ground sites,73921/17/92881,six actual320m original/candidate returns.","EXPLICIT TWO-DOMAIN positive subset73921/17,four nominal320m original/candidate returns with EXACT original sites,spacing and gates. Original three-domain suite remains FAILED at92881 weak-intervention efficacy;this subset does not pass,replace or repair that fixture. Additional independently admitted92881 local trial is separate.").replace("Six320m","Four320m")
	var marker:String="var script:=GDScript.new();script.source_code=code";assert(code.count(marker)==1)
	code=code.replace(marker,'''var positive_guard:String="var reference_heights:Array=[]";assert(code.count(positive_guard)==1)
	code=code.replace(positive_guard,'guards["res://tools/biome_extensions/check_ground_union_positive_walks.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_ground_union_positive_walks.gd")\\n\\t'+positive_guard)
	'''+marker)
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("prepare")
