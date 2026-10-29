extends SceneTree
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_ground_union_worker_walk.gd")
	code=code.replace('const INPUT="res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json"','const INPUT="res://tools/biome_extensions/artifacts/admit_ground_union_additional_site.json"')
	var admission:String="assert(diagnostic.passed and diagnostic.cpu_gpu_source_matches==9);var focus:Vector3=v3(diagnostic.focus)";assert(code.count(admission)==1)
	code=code.replace(admission,'assert(diagnostic.passed and diagnostic.site.seed==92881);var focus:=Vector3(diagnostic.site.point[0],diagnostic.site.canonical_height+2,diagnostic.site.point[2])')
	code=code.replace(".builder(17,true)",".builder(92881,true)").replace("terrain.world_seed=17","terrain.world_seed=92881")
	# This NEW additional case declares5m waypoints BEFORE traversal. The
	# original failed17-point/10m fixture is unchanged and remains preserved.
	code=code.replace("range(17)","range(33)").replace("-80+station*10","-80+station*5").replace("points.size()==17","points.size()==33").replace("points.size()!=17","points.size()!=33")
	var marker:String="var reference_heights:Array=[]";assert(code.count(marker)==1)
	code=code.replace(marker,'guards["res://tools/biome_extensions/check_ground_union_additional_walk.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_ground_union_additional_walk.gd")\n\t'+marker)
	code=code.replace("check_ground_union_worker_walk.json","check_ground_union_additional_walk.json")
	code=code.replace('"scope":"PRIVATE actual','"scope":"ADDITIONAL geometry-admitted positive site on the SAME collider-owning root,126m from the original weak-intervention92881 section. Does NOT replace,repair or pass its preserved failed20mm efficacy gate. This newly frozen cross-section declares5m spacing/33 probes before traversal,with unchanged>=2 actual-structure and>=2 changed-floor20mm gates. PRIVATE actual')
	code=code.replace("at EXACT seed17 ground-boundary cross-section","at the additional frozen92881 shoulder").replace("17 fixed native floor probes","33 fixed native floor probes")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
