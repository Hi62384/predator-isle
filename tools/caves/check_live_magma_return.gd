extends "res://tools/caves/check_live_portal.gd"
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Catalogue:String="res://tools/biome_extensions/artifacts/check_cave_magma_intrusive_source_index_17.json"
var planned:Dictionary={}
var maximum_magma_nodes:int=0
var maximum_molten_nodes:int=0
var observation_ticks:int=0
var maximum_source_lights:int=0
var bound_light_observations:int=0
func fixture_seed()->int:return 17
func fixture_family()->int:return 2
func fixture_cell()->Vector2i:return Vector2i(-73,138)
func fixture_name()->String:return "volcanic"
func report_name()->String:return "check_cave_live_magma_return"
func capture_prefix()->String:return "cave_magma_live"
func render_motion()->bool:return false
func motion_budget_usec()->int:return 650000000
func required_depth()->float:return 250
func fixture_configuration()->Resource:
	guards.merge(Fixture.guards());guards[Catalogue]=FileAccess.get_sha256(Catalogue);var config=Config.new();config.enabled=true;config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));return config
func prepare_live_terrain(terrain,b)->void:
	terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.world_seed=17;terrain.extension_preview="";terrain.grass_preview=false
func fixture_region(b)->Dictionary:
	var work=Workload.new();assert(work.configure(b.settings,fixture_configuration(),17,0));return work.network.region(fixture_cell())
func observe(terrain)->void:
	super.observe(terrain);observation_ticks+=1
	if observation_ticks%120!=0:return
	var magma:int=0;var molten:int=0
	for node in terrain._cave_streamer._cells.values():
		if not is_instance_valid(node):continue
		for child:Node in node.get_children():
			if str(child.name).begins_with("CaveBiome_magma_"):magma+=1
			if str(child.name)=="CaveBiome_magma_molten_volcanic":molten+=1
	maximum_magma_nodes=maxi(maximum_magma_nodes,magma);maximum_molten_nodes=maxi(maximum_molten_nodes,molten)
	var lights:int=0
	for controller in terrain._cave_streamer._biome_runtime_controllers:
		if is_instance_valid(controller.light) and controller.light.visible:
			lights+=1
			if controller.uploaded(terrain._cave_streamer,controller.source_key,controller.source_id):bound_light_observations+=1
	maximum_source_lights=maxi(maximum_source_lights,lights)
func graph_path(topology:Dictionary,source:String,target:String)->Array[String]:
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
	var catalogue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Catalogue));check(catalogue.passed and catalogue.first_molten.site==[-73.0,138.0],"Exact first normal source catalogue site retained")
	var selected:Dictionary=catalogue.first_molten.molten_pools[0];var pool:Dictionary={}
	for candidate:Dictionary in region.get("pools",[]):
		if str(candidate.id)==str(selected.id):pool=candidate;break
	check(not pool.is_empty() and pool.get("fluid_kind","")=="magma" and pool.get("thermal_source","")==selected.thermal_source,"Same actual first source-backed molten basin,not a changed pool or rerolled probability")
	if pool.is_empty():return []
	var target:String=str(pool.id).trim_suffix(":seepage");var topology:Dictionary=Regions.graph(region);var ids:Array[String]=graph_path(topology,str(region.nodes[0].id),target);check(not ids.is_empty() and ids[-1]==target,"Complete actual entrance-to-molten-chamber graph")
	var outward:Array[Vector3]=[];var defaults:int=0;var volcanic:int=0;var length:float=0;var tubes:Array=[]
	for i in range(ids.size()-1):
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if not ((str(edge.from)==ids[i] and str(edge.to)==ids[i+1]) or (str(edge.to)==ids[i] and str(edge.from)==ids[i+1])):continue
			var points:PackedVector3Array=edge.points.duplicate()
			if str(edge.from)!=ids[i]:points.reverse()
			var edge_length:float=0;var distance:float=0
			for station in range(1,points.size()):edge_length+=points[station-1].distance_to(points[station])
			for station in range(points.size()):
				if station>0:distance+=points[station-1].distance_to(points[station])
				var weight:float=float(Regions.along_edge(region.cave_biome_regions,ids[i],ids[i+1],distance,edge_length).weights.get("magma",0));defaults+=int(weight<.01);volcanic+=int(weight>.9);outward.append(points[station]+Vector3(0,.95,0))
			length+=edge_length
			if edge.has("magma_tube_profile"):tubes.append(edge.magma_tube_profile)
			break
	check(defaults>0 and volcanic>0,"Actual surface/Default/cooled-to-source-backed Magma sequence,not a synthetic painted room")
	var route:Array[Vector3]=outward.duplicate()
	for i in range(outward.size()-2,-1,-1):route.append(outward[i])
	route.append(start);planned={"graph_ids":ids,"pool_id":pool.id,"source_kind":pool.heat_source_kind,"source_id":pool.thermal_source,"default_stations":defaults,"magma_stations":volcanic,"tube_profiles":tubes,"one_way_graph_distance_m":length,"outward_waypoints":outward.size(),"pool":pool};return route
func finish(details:Dictionary,scene,walker)->void:
	details["magma_plan"]=planned;details["maximum_native_magma_nodes"]=maximum_magma_nodes;details["maximum_native_molten_nodes"]=maximum_molten_nodes
	details["maximum_source_lights"]=maximum_source_lights;details["bound_light_observations"]=bound_light_observations
	check(maximum_source_lights==1 and bound_light_observations>0,"One actual source-bound light observed during full streamed volcanic return")
	check(maximum_magma_nodes>0 and maximum_molten_nodes>0,"Actual normal cooled geology and real molten shader meshes uploaded during full live return")
	super.finish(details,scene,walker)
func motion_scope()->String:return "Exact FIRST normal molten pool from predeclared six-seed continuation's FIRST17seed/source97x97grid/576originalcave-neighbours,Volcanic17/(-73,138). Normal22percent/300–1100m/depth/surface/source4percent/pool14percent controls unchanged. Surface→actual mouth→Default→cooled volcanic passages→source-backed molten chamber→same surface exit. Original main/fullLOD6/camera50km/four TOTAL workers/180spreload/650smotion/2048MiB/native1.8m/.4m/5mps/45degrees/.6snap/.75drop. Fixed-fps/render-off movement/loading pauses are not uninterrupted FPS/reference art or all-user completion. Saved registry/root unchanged."
