extends "res://tools/caves/check_live_portal.gd"
var metrics
func report_name()->String:return "check_cave_live_rendered_spore"
func capture_prefix()->String:return "cave_rendered_spore"
func render_motion()->bool:return true
func follow_motion_camera()->bool:return true
func motion_fps_limit()->int:return 60
func allow_preload_pauses()->bool:return false
func capture_mid_motion()->bool:return false
func accelerated_worker_yield_usec()->int:return 0
func motion_started(terrain,walker,_camera)->void:
	assert(OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS")=="none","Actual wall-clock test must not use fixed-fps acceleration")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	metrics=preload("res://tools/caves/rendered_walk_metrics.gd").new();metrics.terrain=terrain;metrics.walker=walker;root.add_child(metrics)
	guards["res://tools/caves/rendered_walk_metrics.gd"]=FileAccess.get_sha256("res://tools/caves/rendered_walk_metrics.gd")
func motion_measurements()->Dictionary:
	var result:Dictionary=metrics.finish();check(result.rendered_process_intervals.samples>100,"Positive actual rendered frame sample population");return result
func motion_scope()->String:return "Original Spore seed73921/site(9,-3),normal wall-clock 5mps capsule surface-to-cave-and-same-exit return. Rendering and following eye camera remain active;no fixed-fps acceleration,automatic preload pauses,midpoint captures,temporary light or route correction. FullLOD6/50km/fourtotalworkers/180spreload/420smotion/2048MiB. Actual non-isolated frame timing distributions recorded separately."
