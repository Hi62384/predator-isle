extends SceneTree
const Network=preload("res://tools/caves/cave_network_candidate.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func inspect_region(data:Dictionary)->void:
	check(data.valid and data.entrances.size()>0,"Every admitted component has an explicit surface exit")
	if not data.valid:return
	var reached:Dictionary={data.entrances[0]:true};var changed:bool=true
	while changed:
		changed=false
		for edge:Dictionary in data.edges:
			if reached.has(edge.from) and not reached.has(edge.to):reached[edge.to]=true;changed=true
			if reached.has(edge.to) and not reached.has(edge.from):reached[edge.from]=true;changed=true
	check(reached.size()==data.nodes.size(),"All retained nodes reach the entrance in the undirected return graph")
	check(data.nodes.size()>=13,"Real multi-level3D network,not a single finite room")
	check(data.edges.size()>data.nodes.size()-1,"Actual alternate-route cycle,not only a tree")
	var deepest:float=0
	for node:Dictionary in data.nodes:deepest=maxf(deepest,120-node.point.y)
	check(deepest>=350 and deepest<=398.001,"Deep physical positions below actual surface within finite400m envelope")
	for edge:Dictionary in data.edges:
		check(edge.points.size()>=2 and edge.maximum_grade<=.20001,"Every edge has complete conservative two-way numeric route")
		check(edge.maximum_measured_depth_m<=398.001,"No unbounded/fixed-world-Y depth")
		if not edge.entrance:check(edge.minimum_measured_roof_m>=9.999,"Closed routes preserve sampled local rock cover")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/check_network.gd"]:guards[path]=FileAccess.get_sha256(path)
	var surface:Callable=func(_x:float,_z:float)->float:return 120
	var water:Callable=func(_x:float,_z:float)->float:return 0
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var network=Network.new();network.configure(surface,water,seed_id);network.activity=1
		for cell:Vector2i in [Vector2i.ZERO,Vector2i(-1,-1),Vector2i(4,-7)]:
			var data:Dictionary=network.region(cell);inspect_region(data);var first:PackedByteArray=var_to_bytes(data)
			check(first==var_to_bytes(network.region(cell)),"Warm repeat identical")
			var reference=Network.new();reference.configure(surface,water,seed_id);reference.activity=1;check(first==var_to_bytes(reference.region(cell)),"Cold region generation identical,not load-order-dependent")
			var edge:Dictionary=network.connection(cell,cell+Vector2i.RIGHT);check(not edge.is_empty(),"Actual neighboring admitted regions connect horizontally")
			check(edge==network.connection(cell+Vector2i.RIGHT,cell),"Canonical shared edge independent of query direction")
			cases.append({"seed":seed_id,"cell":str(cell),"nodes":data.nodes.size(),"edges":data.edges.size(),"shared_edge_points":edge.get("points",PackedVector3Array()).size()})
	var network=Network.new();network.configure(surface,water,17);network.activity=1;var original:PackedByteArray=var_to_bytes(network.region(Vector2i.ZERO))
	for i in range(35):network.region(Vector2i(i+10,-2))
	check(network._regions.size()==32 and network._ring.size()==32,"Hard bounded32region descriptor cache")
	check(original==var_to_bytes(network.region(Vector2i.ZERO)),"Eviction does not change regenerated topology/physical route points")
	network.configure(surface,func(_x:float,_z:float)->float:return 140,17);check(not network.region(Vector2i.ZERO).valid,"No accidental underwater entrance or inaccessible flooded component")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private cave network source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_network.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"production_registration":false,"scope":"PRIVATE Default-only shared cave dependency: exit-rooted deterministic3Dmulti-level graph,explicit cycles,canonical symmetric inter-region connections,finite local400mdepth,20percenttwo-way route solver and32region cache. Three seeds/nine signed cells,cold/warm/direction/eviction/underwater controls on independent flat canonical field. Numeric topology/route proof ONLY,not real-world terrain,SDF/mesh/portal/capsule/streaming/art or installed caves. Surface prerequisites and cave biome arrival order remain respected."},"  "));print("CAVE_NETWORK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
func _initialize()->void:call_deferred("run")
