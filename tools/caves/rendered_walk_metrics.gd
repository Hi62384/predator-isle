extends Node
var active:bool=true
var walker
var terrain
var process_ms:Array=[]
var gpu_ms:Array=[]
var cpu_ms:Array=[]
var blocked_readiness_frames:int=0
var last_usec:int=0
func _process(_delta:float)->void:
	if not active:return
	var now:int=Time.get_ticks_usec()
	if last_usec>0:process_ms.append((now-last_usec)/1000.0)
	last_usec=now
	var rid:RID=get_tree().root.get_viewport_rid()
	var gpu:float=RenderingServer.viewport_get_measured_render_time_gpu(rid);var cpu:float=RenderingServer.viewport_get_measured_render_time_cpu(rid)
	if gpu>0:gpu_ms.append(gpu)
	if cpu>0:cpu_ms.append(cpu)
	if is_instance_valid(walker) and is_instance_valid(terrain) and not terrain._cave_streamer.traversal_ready(walker.position):blocked_readiness_frames+=1
static func distribution(values:Array)->Dictionary:
	if values.is_empty():return {"samples":0,"supported":false}
	var sorted:Array=values.duplicate();sorted.sort();var total:float=0;var over33:int=0;var over50:int=0;var over100:int=0
	for value:float in values:total+=value;over33+=int(value>1000.0/30);over50+=int(value>50);over100+=int(value>100)
	return {"supported":true,"samples":values.size(),"mean_ms":total/values.size(),"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.95))],"p99_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.99))],"maximum_ms":sorted[-1],"over33ms_frames":over33,"over50ms_frames":over50,"over100ms_frames":over100}
func finish()->Dictionary:
	active=false
	return {"rendered_process_intervals":distribution(process_ms),"actual_viewport_gpu_ms":distribution(gpu_ms),"actual_viewport_cpu_ms":distribution(cpu_ms),"stream_readiness_missing_process_frames":blocked_readiness_frames,"scope":"Actual rendered wall-clock process intervals during ordinary60Hz physics,with no fixed-fps flag,no automatic preload pauses,no midpoint capture/light interruption,and original geometry/lighting/fullLOD6/50km camera. Other project sessions running;not isolated hardware performance."}
