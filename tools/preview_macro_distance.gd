extends "res://tools/preview_erosion.gd"
func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var focus:=Vector3(5600,247.3867,3840)
	for distance in [80,300,900,2400]:
		await capture(scene,"macro_distance_"+str(distance),focus,Vector3(distance,distance*0.25,0))
	if RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.call("viewport_set_measure_render_time",root.get_viewport_rid(),true)
		var cpu:=0.0;var gpu:=0.0
		for i in range(180):
			await process_frame
			cpu+=float(RenderingServer.call("viewport_get_measured_render_time_cpu",root.get_viewport_rid()))
			gpu+=float(RenderingServer.call("viewport_get_measured_render_time_gpu",root.get_viewport_rid()))
		print("STATIC viewport render CPU/GPU mean ms: ",cpu/180.0," / ",gpu/180.0," (zero means unavailable)")
	scene.queue_free();await process_frame;quit()
