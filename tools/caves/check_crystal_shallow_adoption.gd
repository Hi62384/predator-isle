extends "res://tools/caves/check_crystal_world_cohort.gd"
const Private=preload("res://tools/caves/crystal_shallow_candidate.gd")
const OriginalProvider:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_shallow_candidate_08939bef4e3a/sources/scripts/caves/crystal_features.gd.txt"
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [OriginalProvider,get_script().resource_path,"res://tools/caves/crystal_shallow_candidate.gd","res://tools/caves/shallow_chamber_candidate.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var original:=GDScript.new();original.source_code=FileAccess.get_file_as_string(OriginalProvider);check(original.reload()==OK,"Independent full frozen pre-shallow provider compiles");check(FileAccess.get_sha256("res://scripts/caves/shallow_chambers.gd")==FileAccess.get_sha256("res://tools/caves/shallow_chamber_candidate.gd"),"Production numeric module exact strengthened private source");check(FileAccess.get_file_as_string("res://scripts/caves/crystal_shallow.gd").replace("res://scripts/caves/shallow_chambers.gd","res://tools/caves/shallow_chamber_candidate.gd")==FileAccess.get_file_as_string("res://tools/caves/crystal_shallow_candidate.gd"),"Production wrapper differs only in declared module path")
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");check(definition.validation_errors().is_empty() and definition.feature_configuration.shallow_chambers,"Normal independent shallow switch validates");var off_definition:Resource=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);off_definition.feature_configuration.shallow_chambers=false;var old_definition:Resource=off_definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old_definition.feature_provider=original;var configurations:Array=[]
	for item:Resource in [old_definition,off_definition,definition]:
		var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,item);configurations.append(config)
	var cases:Array=[{"host":"quarry","seed":1002,"site":Vector2i(6,-2),"ordinal":336},{"host":"quarry","seed":1002,"site":Vector2i(9,-3),"ordinal":338},{"host":"crystal_wastes","seed":73921,"site":Vector2i(6,-2)},{"host":"crystal_wastes","seed":19,"site":Vector2i(9,-3)},{"host":"quarry","seed":73921,"site":Vector2i(6,-2)},{"host":"volcanic","seed":17,"site":Vector2i(6,-2)}];var rows:Array=[];var first:Dictionary={};var positives:int=0
	for study:Dictionary in cases:
		var b=owner(study.host,int(study.seed));var works:Array=[];var regions:Array=[]
		for config:Resource in configurations:
			var work=Workload.new();check(work.configure(b.settings,config,int(study.seed),0),"Actual complete original host/seed pipeline validates");works.append(work);regions.append(work.network.region(study.site))
		check(var_to_bytes(regions[0])==var_to_bytes(regions[1]),"Whole independent frozen generator exact in shallow OFF mode")
		var expected:Dictionary=Private.prepare(regions[0],works[0].builder._get_height);check(var_to_bytes(expected)==var_to_bytes(regions[2]),"Actual complete ON generator exact independently strengthened private prototype")
		var added:int=regions[2].get("pockets",[]).size()-regions[0].get("pockets",[]).size();var row:Dictionary={"host":study.host,"seed":study.seed,"site":[study.site.x,study.site.y],"added":added};check(added in [0,1] and var_to_bytes(regions[2].nodes)==var_to_bytes(regions[0].nodes) and var_to_bytes(regions[2].edges)==var_to_bytes(regions[0].edges),"Bounded addition with complete original main nodes/routes exact")
		if study.has("ordinal"):
			check(added==1,"BOTH original2070case normal positive sites retained")
			if added==1:
				positives+=1;var room:Dictionary=regions[2].pockets[-1];var coverage:Dictionary=Regions.along_edge(regions[2].cave_biome_regions,str(room.id),str(room.id),0,0);var depth:float=works[2].builder._get_height(room.point.x,room.point.z)-room.point.y;check(depth<40 and depth>=24 and coverage.weights.get("crystal",0)>=.8,"Actual normal production shallow Crystal coverage,not relabelled graph tier");row["room"]=room;row["ordinal"]=study.ordinal;row["depth_m"]=depth;row["theme"]=coverage.candidate_ids.get("crystal","")
				if first.is_empty():first=row.duplicate(true)
		if study.host=="crystal_wastes" and int(study.seed)==19:check(var_to_bytes(regions[2])==var_to_bytes(regions[0]),"Original first normally rare luminous region geography unchanged")
		rows.append(row)
	check(positives==2 and not first.is_empty(),"Both original normal positives accepted through actual production provider")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Unchanged full shallow adoption source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"first_positive":first,"positives":positives,"scope":"Actual complete production region generator versus FULL independent frozen pre-shallow Script provider and strengthened private prototype. Whole OFF/ON dictionaries exact,six fixed positive/negative cases,both original2070case normal positives retained,original nodes/routes unchanged,real24–40m Crystal coverage and unchanged first normally rare luminous region. Not new native production physics/FPS/art acceptance."},"  "));print("SHALLOW_PRODUCTION_ADOPTION ",checks," rows=",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
