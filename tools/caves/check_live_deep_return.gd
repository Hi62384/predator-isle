extends "res://tools/caves/check_live_portal.gd"
func report_name()->String:return "check_cave_live_deep_return"
func render_motion()->bool:return false
func motion_budget_usec()->int:return 650000000
func required_depth()->float:return 300
func motion_scope()->String:return "Original actual Spore seed73921/cell(9,-3),surface-to-deepest canonical graph chamber(~360m local depth)and reverse via actual graph edges0/5/10/15 (not a preloaded private scene). Full original terrain workers/cut changes/native capsule and independent neighboring-region links participate. Fixed60Hz accelerated diagnostic with explicit loading pauses;render loop disabled ONLY during movement to isolate physics/streaming,not a GPU/frame-time certificate. Before/after actual GPU images remain included;temporary debug-light chamber view is separately labelled,not production lighting."
func planned_route(region:Dictionary,start:Vector3)->Array[Vector3]:
	var outward:Array[Vector3]=[]
	for edge_id:int in [0,5,10,15]:
		check(edge_id<region.edges.size(),"Original graph retains every required deep descent edge")
		if edge_id>=region.edges.size():return []
		for point:Vector3 in region.edges[edge_id].points:outward.append(point+Vector3(0,.95,0))
	check(region.nodes[-1].level==3 and outward[-1].y<region.nodes[1].point.y-250,"Declared destination reaches genuine deep local depth,not only first chamber")
	var route:Array[Vector3]=outward.duplicate()
	for i in range(outward.size()-2,-1,-1):route.append(outward[i])
	route.append(start);return route
