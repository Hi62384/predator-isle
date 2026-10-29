extends "res://tools/caves/check_crystal_world_cohort.gd"
func run()->void:
	var guards:Dictionary={get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)};var records:Array=[];var first:Dictionary={};var positives:int=0;var source:Dictionary={};var reports:Array=[]
	for batch in range(9):
		var path:String="res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_batch_"+str(batch)+".json";check(FileAccess.file_exists(path),"Fixed batch present "+str(batch))
		if not FileAccess.file_exists(path):continue
		var report=JSON.parse_string(FileAccess.get_file_as_string(path));check(report is Dictionary and report.get("passed",false) and int(report.get("batch",-1))==batch,"Complete successful fixed batch "+str(batch))
		if not report is Dictionary or not report.get("passed",false):continue
		guards[path]=FileAccess.get_sha256(path)
		if source.is_empty():source=report.source_sha256.duplicate()
		check(report.source_sha256==source,"Every fixed batch used the same complete guarded runtime/candidate source")
		check(int(report.first_ordinal)==records.size(),"Exact contiguous original ordinal prefix "+str(batch))
		for row:Dictionary in report.records:
			check(int(row.ordinal)==records.size(),"No missing,duplicated or substituted actual world case")
			if int(row.added)==1:
				positives+=1
				if first.is_empty():first=row.duplicate(true)
			records.append(row)
		check(int(report.last_ordinal_exclusive)==records.size(),"Complete declared batch interval")
		reports.append({"path":path,"checks":report.checks,"cases":report.records.size(),"positives":report.positives})
	check(records.size()==2070 and reports.size()==9 and positives>0,"ALL2070predeclared cases/all9batches completed with positive actual normal shallow Crystal branch")
	guards.merge(source)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Unchanged complete aggregate input "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"batches":reports,"positives":positives,"first_positive":first,"maximum_survey_workers":3,"scope":"PRIVATE full2070fixed normal actual cases,original918prefix and every rejection retained;all9bounded sequential native batches,3pure numeric workers each,same unchanged guarded runtime/candidate source. No new lottery/anchor/extent/depth preference;pre-existing Crystal reach must cover real24–40m chamber. Original nodes/routes/distances retained. Positive descriptor is not native Crystal geometry/traversal/adoption/FPS/art completion."},"  "));print("CRYSTAL_SHALLOW_AGGREGATE ",checks," positives=",positives," cases=",records.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
