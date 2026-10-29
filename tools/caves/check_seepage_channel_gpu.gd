extends "res://tools/caves/check_geology_gpu.gd"
func image_prefix()->String:return "cave_seepage_channel"
func report_name()->String:return "check_cave_seepage_channel_gpu"
func target_pool(region:Dictionary)->Dictionary:
	for pool:Dictionary in region.get("pools",[]):
		if pool.has("stream_points"):return pool
	return {}
