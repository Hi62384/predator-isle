extends "res://tools/biome_extensions/check_all.gd"
const Batch=preload("res://scripts/caves/surface_batch.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/surface_batch.gd","res://tools/caves/check_surface_batch.gd"]:guards[path]=FileAccess.get_sha256(path)
	var columns:Dictionary={}
	for z in range(-3,1):
		for x in range(-2,2):columns[Vector2i(x,z)]=true
	var request:Dictionary={"columns":columns,"snapshot":{"records":[]}};var batch=Batch.new();check(batch.configure(71,4,request),"Bounded complete surface batch accepted");var tasks:Array=[];var unique:Dictionary={}
	while batch.pending():
		var task:Dictionary=batch.take();tasks.append(task)
		for column:Vector2i in task.columns:check(not unique.has(column),"Exactly one group owns each complete64m column");unique[column]=true
	check(tasks.size()==4 and unique==columns,"At most four groups cover full original mask without partial columns")
	check(not batch.assemble().valid,"No incomplete set can expose a hole")
	for index in range(tasks.size()-1,-1,-1):
		var task:Dictionary=tasks[index];var cells:Array=[]
		for column:Vector2i in task.columns:cells.append({"key":Vector3i(column.x,1,column.y),"valid":true,"groups":{}})
		var data:Dictionary={"valid":true,"owned_columns":task.columns,"columns":columns,"cells":cells,"ground":{"parent":{"valid":true}} if index==0 else {}}
		check(not batch.accept(70,4,index,data) and not batch.accept(71,3,index,data),"Stale batch/generation results cannot mutate current assembly")
		check(batch.accept(71,4,index,data),"Reverse worker completion order accepted")
		check(not batch.accept(71,4,index,data),"Duplicate worker result rejected")
		check(batch.complete()==(index==0),"Complete flag only after every owned column group returns")
	var complete:Dictionary=batch.assemble();check(complete.valid and complete.cells.size()==16 and complete.columns==columns and complete.ground.size()==1,"Complete canonical result retains original full mask and prepared ground")
	var invalid=Batch.new();check(invalid.configure(72,5,request),"Independent failure control configured");var task:Dictionary=invalid.take();check(not invalid.accept(72,5,task.part,{"valid":true,"columns":columns,"owned_columns":{}}) and not invalid.assemble().valid,"Wrong owner set never produces a partial surface commit")
	var empty=Batch.new();check(not empty.configure(1,1,{"columns":{}}),"Empty mask cannot create an active batch")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable surface batch source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_batch.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"groups":tasks.size(),"columns":columns.size(),"scope":"Pure main-thread complete-result assembly for bounded four-way numeric extraction:exact column ownership,reverse completion,stale/duplicate/invalid negatives and no partial readiness. Not yet wired to worker scheduling or live surface commit."},"  "));print("CAVE_SURFACE_BATCH ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
