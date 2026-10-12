extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sample_rows(builder: RefCounted,chunk: int,first: int,end: int,result: Array) -> void:
	var checksum:=0.0
	for z in range(first,end):
		for x in range(131):
			checksum+=builder._get_height(chunk*256.0+(x-1)*2.0,(z-1)*2.0)
	result[0]=checksum

func trial(blocks: int) -> Vector2:
	var start:=Time.get_ticks_usec()
	var checksum:=0.0
	var jobs: Array=[]
	var next:=0
	while next<4*blocks or not jobs.is_empty():
		while next<4*blocks and jobs.size()<4:
			var builder=load("res://scripts/terrain_mesh_builder.gd").new()
			builder.settings=load("res://terrain_settings.tres").duplicate(true)
			builder._configure_noise()
			var chunk:=next/blocks
			var block:=next%blocks
			var first:=block*131/blocks
			var end: int=(block+1)*131/blocks
			var result: Array=[0.0]
			var task:=WorkerThreadPool.add_task(func(): sample_rows(builder,chunk,first,end,result))
			jobs.append({"task":task,"result":result})
			next+=1
		for i in range(jobs.size()-1,-1,-1):
			if WorkerThreadPool.is_task_completed(jobs[i].task):
				WorkerThreadPool.wait_for_task_completion(jobs[i].task)
				checksum+=jobs[i].result[0]
				jobs.remove_at(i)
		if not jobs.is_empty(): await process_frame
	return Vector2((Time.get_ticks_usec()-start)/1000.0,checksum)

func run() -> void:
	var results: Dictionary={"scope":"Canonical padded height sampling only, four 128-resolution chunks; max four concurrent jobs. Not a complete alternate mesh builder.","chunk_ms":[],"four_row_blocks_ms":[]}
	for repeat in range(3):
		var whole: Vector2=await trial(1)
		var rows: Vector2=await trial(4)
		assert(is_equal_approx(whole.y,rows.y))
		results.chunk_ms.append(whole.x)
		results.four_row_blocks_ms.append(rows.x)
	print(JSON.stringify(results))
	FileAccess.open("res://tools/job_granularity.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit()
