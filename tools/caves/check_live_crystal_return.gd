extends "res://tools/caves/check_live_portal.gd"
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
var planned:Dictionary={}
var maximum_native_crystal_nodes:int=0
var crystal_observe_ticks:int=0
func observe(terrain)->void:
	super.observe(terrain);crystal_observe_ticks+=1
	if crystal_observe_ticks%1200!=0:return
	var count:int=0
	for node in terrain._cave_streamer._cells.values():
		if not is_instance_valid(node):continue
		for child:Node in node.get_children():
			if str(child.name).begins_with("CaveBiome_crystal_"):count+=1
	maximum_native_crystal_nodes=maxi(maximum_native_crystal_nodes,count)
func report_name()->String:return "check_cave_live_crystal_return"
func fixture_family()->int:return 5
func fixture_cell()->Vector2i:return Vector2i(6,-2)
func fixture_name()->String:return "crystal_wastes"
func capture_prefix()->String:return "cave_crystal_live"
func render_motion()->bool:return false
func motion_budget_usec()->int:return 650000000
func required_depth()->float:return 300
func fixture_configuration()->Resource:
	guards.merge(Fixture.guards());var config=Config.new();config.enabled=true;config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));return config
func fixture_region(b)->Dictionary:
	var work=Workload.new();assert(work.configure(b.settings,fixture_configuration(),73921,0));return work.network.region(fixture_cell())
func path(topology:Dictionary,source:String,target:String)->Array[String]:
	var distances:Dictionary={source:0.0};var previous:Dictionary={};var done:Dictionary={}
	for iteration in range(topology.nodes.size()):
		var nearest:String="";var distance:float=INF;var ids:Array=distances.keys();ids.sort()
		for id:String in ids:
			if not done.has(id) and float(distances[id])<distance:nearest=id;distance=float(distances[id])
		if nearest.is_empty() or nearest==target:break
		done[nearest]=true
		for index:int in topology.adjacency[nearest]:
			var edge:Dictionary=topology.edges[index];var other:String=edge.to if edge.from==nearest else edge.from;var proposed:float=distance+edge.length
			if proposed<float(distances.get(other,INF)):distances[other]=proposed;previous[other]=nearest
	var result:Array[String]=[target]
	while result[0]!=source and result.size()<128:
		if not previous.has(result[0]):return []
		result.push_front(previous[result[0]])
	return result if result[0]==source else []
func planned_route(region:Dictionary,start:Vector3)->Array[Vector3]:
	# Exact first three positive anchors from the complete126case normal-world
	# cohort,including its FIRST134m lobe and260/360m deeper Crystal stations.
	var targets:Array[String]=["6:-2:1:2:lobe:1","6:-2:2:0","6:-2:3:0"];var topology:Dictionary=Regions.graph(region);var source:String=str(region.nodes[0].id);var from:String=source;var identities:Array[String]=[source]
	for target:String in targets:
		check(topology.nodes.has(target),"Original normal-settings preselected Crystal anchor retained "+target)
		var selected:bool=false
		for candidate:Dictionary in region.cave_biome_regions.candidates:
			if candidate.biome_id=="crystal" and candidate.anchor==target:selected=true
		check(selected,"Same preselected normal chance/depth/size/surface positive,not forced/rerolled "+target)
		var section:Array[String]=path(topology,from,target);check(not section.is_empty(),"Original traversable graph reaches selected Crystal anchor "+target)
		for i in range(1,section.size()):identities.append(section[i])
		from=target
	var outward:Array[Vector3]=[];var default_count:int=0;var crystal_count:int=0;var length_m:float=0
	for i in range(identities.size()-1):
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if not ((str(edge.from)==identities[i] and str(edge.to)==identities[i+1]) or (str(edge.to)==identities[i] and str(edge.from)==identities[i+1])):continue
			var points:PackedVector3Array=edge.points.duplicate()
			if str(edge.from)!=identities[i]:points.reverse()
			var edge_length:float=0;var station:float=0
			for j in range(1,points.size()):edge_length+=points[j-1].distance_to(points[j])
			for j in range(points.size()):
				if j>0:station+=points[j-1].distance_to(points[j])
				var amount:float=float(Regions.along_edge(region.cave_biome_regions,identities[i],identities[i+1],station,edge_length).weights.get("crystal",0));default_count+=int(amount<.01);crystal_count+=int(amount>.9);outward.append(points[j]+Vector3(0,.95,0))
			length_m+=edge_length;break
	check(default_count>0 and crystal_count>0,"Complete actual route includes both Default and full-strength Crystal,not one painted synthetic room")
	var route:Array[Vector3]=outward.duplicate()
	for i in range(outward.size()-2,-1,-1):route.append(outward[i])
	route.append(start);planned={"targets":targets,"graph_ids":identities,"default_stations":default_count,"crystal_stations":crystal_count,"one_way_graph_distance_m":length_m,"outward_waypoints":outward.size()};return route
func finish(details:Dictionary,scene,walker)->void:
	details["crystal_plan"]=planned
	details["maximum_observed_native_crystal_mesh_nodes"]=maximum_native_crystal_nodes
	check(maximum_native_crystal_nodes>0,"Positive actual native Crystal geometry was uploaded during complete live traversal,not scalar labels alone")
	if is_instance_valid(scene):
		var stream=scene.get_node("Terrain")._cave_streamer;var count:int=0
		for node in stream._cells.values():
			if not is_instance_valid(node):continue
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_crystal_"):count+=1
		details["final_native_crystal_mesh_nodes"]=count
	super.finish(details,scene,walker)
func motion_scope()->String:return "Normal requested18percent/350–1500m/5,20,50,80,100/depth/surface Crystal,regional activity.85. First positive original CrystalWastes73921/(6,-2) cohort site,its FIRST134m anchor then original260/360m positive anchors,all actual graph points/same surface exit. No altered probability/size/depth/rerolled site. Actual original main scene/fullLOD6/camera50km/four TOTAL workers/original180spreload/deep650smotion gates. Native1.8m/.4m/5mps/45degree/.6snap/.75drop/same-surface return. Fixed-fps acceleration/render-off movement/explicit loading pauses NOT uninterrupted FPS/art/whole-user completion. Saved world registry/root activation unchanged."
