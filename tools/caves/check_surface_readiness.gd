extends "res://tools/biome_extensions/check_all.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
class Transaction extends RefCounted:
	var committed:bool=true
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/streamer.gd","res://scripts/caves/workload.gd","res://tools/caves/check_surface_readiness.gd"]:guards[path]=FileAccess.get_sha256(path)
	var stream=Streamer.new();stream.configuration=Config.new();stream._bundle={"entrances":[{"point":Vector3(0,100,0),"minimum_exposed_floor":80.0,"columns":{Vector2i.ZERO:true}}]};stream._cells={Vector3i.ZERO:null,Vector3i(0,1,0):null}
	check(stream.traversal_ready(Vector3(10,20,10)),"Loaded deep passage does not wait for unrelated surface entrance above it")
	check(stream.nearby_columns(Vector3(10,20,10)).size()==1,"Nearby overhead mouth may preload early without blocking already-loaded deep passage")
	check(not stream.traversal_ready(Vector3(10,90,10)),"Exposed approach remains gated while mouth transaction is missing")
	check(stream.nearby_columns(Vector3(10,90,10)).size()==1,"Actual exposed approach still requests complete opening")
	stream._surface_transaction=Transaction.new();stream._surface_columns={Vector2i.ZERO:true};check(stream.traversal_ready(Vector3(10,90,10)),"Committed complete mouth releases readiness gate")
	stream._surface_columns={};check(not stream.traversal_ready(Vector3(10,90,10)),"Incomplete committed column set cannot release mouth gate")
	check(stream.traversal_ready(Vector3(10,20,10)),"Incomplete unrelated surface cannot block already-loaded deep volume")
	check(not stream.traversal_ready(Vector3(128,20,10)),"Missing actual cave cell remains unready regardless of mouth state")
	stream.free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable readiness source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_readiness.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"scope":"Actual streamer readiness policy with loaded-cell and committed-column controls:surface approaches wait for complete mouth;deep passages beneath it do not. Measured minimum exposed route altitude,not arbitrary worldY or a fake surface ID. Native seal and long-return acceptance remain separate."},"  "));print("CAVE_SURFACE_READINESS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
