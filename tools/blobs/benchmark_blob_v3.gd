extends SceneTree
const Pipeline=preload("res://scripts/blobs/blob_organism_pipeline.gd")
class CancelJob extends RefCounted:
	var cancelled:=false
	func is_cancelled()->bool: return cancelled
	func set_progress(_value:float,message:String)->void:
		if message=="Calibrating closed-shell volume": cancelled=true
func _initialize()->void: call_deferred("run")
func run()->void:
	var rows:Array=[]
	for quality in 2:
		var started:=Time.get_ticks_usec()
		var data:=Pipeline.new().build(5103,quality,"hybrid",7,null,{"profile":"tendril","body_plan":"multilobe"})
		if data.has("error"): push_error(str(data)); quit(1); return
		rows.append({"quality":quality,"cold_generation_ms":float(Time.get_ticks_usec()-started)/1000.0,"triangles":data.statistics.triangles,"volume_samples":data.dna.volume_curve.size()}); print(rows[-1])
	var cancelled:=Pipeline.new().build(5103,0,"auto",7,CancelJob.new())
	var success:bool=cancelled.get("cancelled",false)
	var file:=FileAccess.open("res://data/blobs_v3/generation_benchmark.json",FileAccess.WRITE); file.store_string(JSON.stringify({"models":rows,"cancellation_at_volume_pass":success},"\t")); file.close()
	print("BENCHMARK_COMPLETE cancelled=",success); quit(0 if success else 1)
