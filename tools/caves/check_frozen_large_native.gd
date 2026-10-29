extends "res://tools/caves/check_frozen_features.gd"
func report_name()->String:return "check_cave_frozen_large_native"
func shore_route()->Array[Vector3]:
	# Larger deposit now covers the old static spawn. Start on the unchanged
	# room floor and retain EVERY original shore/lake waypoint in both directions.
	var route:Array[Vector3]=super.shore_route();route.push_front(Vector3(32,20.95,32));route.append(Vector3(32,20.95,32));return route
func fixture()->Dictionary:
	var region:Dictionary=super.fixture()
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	return Features.new().decorate_region(region,height,73921,load("res://config/caves/biomes/frozen_cave_definition.tres").feature_configuration,400,10)
