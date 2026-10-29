extends "res://tools/blobs/render_blob_v4_sheets.gd"
class CancelJob extends RefCounted:
	var cancelled:=false
	func is_cancelled()->bool:return cancelled
	func set_progress(_value:float,message:String)->void:
		if message=="Extracting composed anatomy":cancelled=true
func _run()->void:
	var models:Array=[];var rows:Array=[]
	for quality in 2:
		var started:=Time.get_ticks_usec()
		var data:=Pipeline.new().build(5101,quality,"vine",7,null,{"profile":"tendril","body_plan":"flattened"})
		if data.has("error"):push_error(str(data));quit(1);return
		rows.append({"quality":quality,"cold_generation_ms":float(Time.get_ticks_usec()-started)/1000,"triangles":data.statistics.triangles,"packed_geometry_bytes":data.statistics.packed_bytes})
		models.append(data);print("V4_BENCH_GENERATION ",rows[-1])
	var started:=Time.get_ticks_usec()
	var cancelled:=Pipeline.new().build(5101,0,"vine",7,CancelJob.new())
	var cancellation:Dictionary={"success":cancelled.get("cancelled",false),"elapsed_ms":float(Time.get_ticks_usec()-started)/1000}
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);_tile(viewport,models[0],false)
	var actor:Node3D=active_organisms[0];actor.speed=.6
	for i in 30:actor.simulate(1.0/60);await process_frame
	var cpu:Array[float]=[];var wall:Array[float]=[]
	for i in 120:
		started=Time.get_ticks_usec();actor.simulate(1.0/60);cpu.append(float(Time.get_ticks_usec()-started)/1000)
		await process_frame;await RenderingServer.frame_post_draw
		wall.append(float(Time.get_ticks_usec()-started)/1000)
	cpu.sort();wall.sort()
	var result:Dictionary={"seed":5101,"generation":rows,"cancellation_before_extraction":cancellation,"animation_ms":{"mean":_mean(cpu),"p95":cpu[113],"max":cpu[-1]},"frame_ms_including_render_and_vsync":{"mean":_mean(wall),"p95":wall[113],"max":wall[-1]},"viewport":"1280x720","renderer":"Compatibility","gpu":RenderingServer.get_video_adapter_name(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"process_static_memory_bytes":OS.get_static_memory_usage(),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"notes":"One draft creature; CPU includes contact/curve guards. Frame wall time includes the Godot root viewport, vsync and scheduling. No crowd or game FPS claim."}
	var f:=FileAccess.open("res://data/blobs_v4/performance_benchmark.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();print("V4_BENCH_COMPLETE ",result);quit(0 if cancellation.success else 1)
func _mean(values:Array[float])->float:
	var total:=.0
	for value in values:total+=value
	return total/values.size()
