extends "res://tools/biome_extensions/check_all.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
class Host extends Node3D:
	var cave_settings=Config.new()
	var upload_budget_ms:float=0
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/streamer.gd","res://tools/caves/check_queue_refill.gd"]:guards[path]=FileAccess.get_sha256(path)
	var host_node:=Host.new();var stream=Streamer.new();stream.initialize(host_node);stream._region=Vector2i.ZERO;stream._last_plan=Vector3.ZERO
	var keys:Array[Vector3i]=[]
	for z in range(-1,3):
		for x in range(-1,3):keys.append(Vector3i(x,0,z))
	stream._bundle={"cell":Vector2i.ZERO,"cells":keys,"regions":[],"connections":[]}
	for key:Vector3i in keys:stream._wanted[key]=true
	for index in range(8):stream._ready.append({"key":keys[index],"valid":true,"arrays":[]})
	stream._inflight[keys[8]]=stream._generation;var selected:PackedByteArray=var_to_bytes(stream._wanted)
	# Zero upload budget deliberately retains seven completed results after
	# consuming one. No new worker is allowed,so this isolates queue policy.
	stream.tick(Vector3.ZERO,Vector3.ZERO,0,true)
	check(stream._cells.size()==1 and stream._ready.size()==7,"Positive upload backlog remains while refill occurs")
	check(var_to_bytes(stream._wanted)==selected,"Stationary refill preserves selected cell order without reranking whole regional field")
	var completed:Dictionary={}
	for result:Dictionary in stream._ready:completed[result.key]=true
	var unique:Dictionary={}
	for key:Vector3i in stream._pending:
		check(not completed.has(key) and not stream._cells.has(key) and not stream._inflight.has(key),"Completed/present/inflight cells are never resubmitted as duplicate mesh jobs")
		check(not unique.has(key),"No duplicate pending key");unique[key]=true
	check(stream._pending.size()==7,"All and only genuinely unsubmitted selected cells refill,within12-job bound")
	stream.shutdown();stream.free();host_node.free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable refill source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_queue_refill.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"scope":"Actual streamer with positive completed-result upload backlog and occupied inflight key:stationary refill retains selected order and queues only genuinely unsubmitted cells. No worker/GPU throughput claim;live integration has separate gates."},"  "));print("CAVE_QUEUE_REFILL ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
