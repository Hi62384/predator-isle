extends RefCounted
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_ground_union_trial_4da5146ad6b0/sources/tools/biome_extensions/artifacts/"
static func source_for(local:bool,caller:String)->String:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_ground_union_worker_walk.gd")
	var input:String=FROZEN+("admit_ground_union_additional_site.json.txt" if local else "diagnose_tissue_ground_boundary.json.txt")
	code=code.replace('const INPUT="res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json"','const INPUT="'+input+'"')
	var original_guard:String='for path:String in diagnostic.source_sha256:assert(FileAccess.get_sha256(path)==diagnostic.source_sha256[path]);guards[path]=diagnostic.source_sha256[path]';assert(code.count(original_guard)==1)
	code=code.replace(original_guard,'''var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	for path:String in ["res://data/surface_regression_20261018.json","res://tools/biome_extensions/registered_grounded_walks.gd","'''+caller+'''"]:guards[path]=FileAccess.get_sha256(path)''')
	assert(code.count("Fixture.configure(terrain,enabled);")==1);code=code.replace("Fixture.configure(terrain,enabled);","")
	var settings:String="terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);";assert(code.count(settings)==1);code=code.replace(settings,settings+"terrain.settings.alien_infected.hive_grounded_shoulders=enabled;")
	var committed:String="await settle(terrain)";assert(code.count(committed)==1);code=code.replace(committed,committed+';check(terrain._settings_snapshot.alien_infected.hive_grounded_shoulders==enabled,"Actual production configured geometry setting")')
	if local:
		var admission:String="assert(diagnostic.passed and diagnostic.cpu_gpu_source_matches==9);var focus:Vector3=v3(diagnostic.focus)";assert(code.count(admission)==1)
		code=code.replace(admission,'assert(diagnostic.passed and diagnostic.site.seed==92881);var focus:=Vector3(diagnostic.site.point[0],diagnostic.site.canonical_height+2,diagnostic.site.point[2])')
		code=code.replace(".builder(17,true)",".builder(92881,true)").replace("terrain.world_seed=17","terrain.world_seed=92881")
		code=code.replace("range(17)","range(13)").replace("-80+station*10","-30+station*5").replace("points.size()==17","points.size()==13").replace("points.size()!=17","points.size()!=13")
		var route:String="for index in range(1,points.size()):route.append(points[index])\n\t\tfor index in range(points.size()-2,-1,-1):route.append(points[index])";assert(code.count(route)==1)
		code=code.replace(route,"for index in range(7,13):route.append(points[index])\n\t\tfor index in range(11,-1,-1):route.append(points[index])\n\t\tfor index in range(1,7):route.append(points[index])").replace("points[0]","points[6]")
		var floor_marker:String="points.append(hit.position+Vector3(0,.95,0));";assert(code.count(floor_marker)==1);code=code.replace(floor_marker,'check(hit.normal.y>=cos(deg_to_rad(45)),"Every original local floor sample respects45degree grade");'+floor_marker)
		code=code.replace("check_ground_union_worker_walk.json","check_grounded_local_walk.json").replace("Actual320m shoulder","Actual120m local shoulder")
		code=code.replace('"scope":"PRIVATE actual','"scope":"REGISTERED actual setting at the separately frozen additional92881 LOCAL shoulder,centre/+30m/-30m/centre,nominal120m. Original weak-intervention20mm gate and failed80m long approach remain FAILED,not replaced or repaired. Actual unmodified production controller,independent Resource bool false/true. Actual')
		code=code.replace("at EXACT seed17 ground-boundary cross-section","at the frozen additional92881 shoulder").replace("17 fixed native floor probes","13 fixed native floor probes").replace("Two320m capsule returns","Two120m local capsule returns")
	else:
		var begin:int=code.find("\tfor enabled:bool in [false,true]:");var end:int=code.find("\tfor path:String in guards:",begin);assert(begin>0 and end>begin);var indented:String=""
		for line:String in code.substr(begin,end-begin).split("\n"):
			if not line.is_empty():indented+="\t"+line+"\n"
		var prefix:String='''	var views_path:String="'''+FROZEN+'''render_tissue_variation_registered.json.txt";var views=JSON.parse_string(FileAccess.get_file_as_string(views_path));assert(views.passed);guards[views_path]=FileAccess.get_sha256(views_path)
	for seed_id:int in [73921,17]:
		var found:bool=false
		for view:Dictionary in views.views:
			if view.seed==seed_id and view.view=="ground":focus=v3(view.focus);p=Vector2(focus.x,focus.z);found=true;break
		assert(found);reference_heights=[]
'''
		code=code.substr(0,begin)+prefix+indented+code.substr(end);code=code.replace(".builder(17,true)",".builder(seed_id,true)").replace("terrain.world_seed=17","terrain.world_seed=seed_id").replace('records.append({"candidate_enabled":enabled','records.append({"seed":seed_id,"candidate_enabled":enabled')
		code=code.replace("check_ground_union_worker_walk.json","check_grounded_positive_walks.json")
		code=code.replace('"scope":"PRIVATE actual','"scope":"REGISTERED TWO original positive domains73921/17,EXACT original frozen sections/10m spacing/20mm efficacy and physical limits. Original three-domain suite remains FAILED at weak92881 efficacy and is not replaced or repaired. Actual unmodified production controller,independent Resource bool false/true. Actual')
		code=code.replace("at EXACT seed17 ground-boundary cross-section","at each original frozen positive cross-section").replace("Two320m capsule returns","Four nominal320m capsule returns")
	code=code.replace("Actual inherited ChunkTerrain overrides only its original dispatch generator constructor;","NO private script/dispatch/generator substitution;").replace("No production edits.","Actual registered Resource control exercised.")
	return code
