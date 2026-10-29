extends "res://tools/caves/check_live_insect_return.gd"
func report_name()->String:return "check_cave_live_insect_frontier_return"
func capture_prefix()->String:return "cave_insect_frontier_live"
func motion_scope()->String:return super.motion_scope()+" Default-on temporary frontier render/physical closures and approaching-neighbour readiness are active. This run records engine --fixed-fps acceleration separately;not uninterrupted real-time/FPS acceptance."
