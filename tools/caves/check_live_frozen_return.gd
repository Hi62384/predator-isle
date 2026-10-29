extends "res://tools/caves/check_live_portal.gd"
const FrozenFixture=preload("res://tools/caves/frozen_fixture.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Frozen=preload("res://scripts/caves/frozen_features.gd")
var planned:Dictionary={}
func report_name()->String:return "check_cave_live_frozen_return"
func fixture_seed()->int:return 17
func fixture_name()->String:return "grass"
func capture_prefix()->String:return "cave_frozen_live"
func render_motion()->bool:return false
func required_depth()->float:return 100
func fixture_builder():
	var b=make_builder(1,17);b.settings.wise_mountains_coverage=0;b.settings.grass_coverage=100;b._configure_noise();return b
func fixture_configuration()->Resource:
	guards.merge(FrozenFixture.guards())
	var config=Config.new();config.enabled=true;config.biome_regions=config.biome_regions.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/frozen_cave_definition.tres"));return config
func prepare_live_terrain(terrain,b)->void:
	terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.world_seed=17;terrain.extension_preview="";terrain.grass_preview=false
func fixture_region(b)->Dictionary:
	var work=Workload.new();assert(work.configure(b.settings,fixture_configuration(),17,0));return work.network.region(fixture_cell())
func planned_route(region:Dictionary,start:Vector3)->Array[Vector3]:
	var pool:Dictionary={}
	for candidate:Dictionary in region.get("pools",[]):
		if candidate.id=="9:-3:1:3:lobe:1:seepage":pool=candidate
	check(not pool.is_empty(),"Same original preselected wet Frozen basin,not replacement after a failure")
	if pool.is_empty():return []
	var target:String=str(pool.id).trim_suffix(":seepage");var topology:Dictionary=Regions.graph(region);var source:String=str(region.nodes[0].id);var distances:Dictionary={source:0.0};var previous:Dictionary={};var done:Dictionary={}
	for iteration in range(topology.nodes.size()):
		var nearest:String="";var distance:float=INF
		for id in distances:
			if not done.has(id) and float(distances[id])<distance:nearest=id;distance=float(distances[id])
		if nearest.is_empty() or nearest==target:break
		done[nearest]=true
		for index:int in topology.adjacency[nearest]:
			var edge:Dictionary=topology.edges[index];var other:String=edge.to if edge.from==nearest else edge.from;var proposed:float=distance+edge.length
			if proposed<float(distances.get(other,INF)):distances[other]=proposed;previous[other]=nearest
	check(distances.has(target),"Frozen chamber connected through actual original graph")
	var identities:Array[String]=[target]
	while identities[0]!=source and identities.size()<128:
		if not previous.has(identities[0]):break
		identities.push_front(previous[identities[0]])
	check(identities[0]==source,"Complete entrance-to-Frozen graph path,not a disconnected blue room")
	var outward:Array[Vector3]=[];var default_count:int=0;var frozen_count:int=0
	for i in range(identities.size()-1):
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if not ((str(edge.from)==identities[i] and str(edge.to)==identities[i+1]) or (str(edge.to)==identities[i] and str(edge.from)==identities[i+1])):continue
			var points:PackedVector3Array=edge.points.duplicate()
			if str(edge.from)!=identities[i]:points.reverse()
			var length_m:float=0;var station:float=0
			for j in range(1,points.size()):length_m+=points[j-1].distance_to(points[j])
			for j in range(points.size()):
				if j>0:station+=points[j-1].distance_to(points[j])
				var amount:float=float(Regions.along_edge(region.cave_biome_regions,identities[i],identities[i+1],station,length_m).weights.get("frozen",0));default_count+=int(amount<.01);frozen_count+=int(amount>.9);outward.append(points[j]+Vector3(0,.95,0))
			break
	var ice:=Vector3(pool.center.x,pool.water_y+Frozen.ICE_FREEBOARD+.95,pool.center.z);outward.append(ice);check(default_count>0 and frozen_count>0,"Physical path includes both actual Default and full-strength Frozen geography")
	var route:Array[Vector3]=outward.duplicate()
	for i in range(outward.size()-2,-1,-1):route.append(outward[i])
	route.append(start);planned={"graph_ids":identities,"default_stations":default_count,"frozen_stations":frozen_count,"pool_id":pool.id,"pool_radius":pool.radius,"large_lake":pool.get("frozen_lake",false),"ice_target":str(ice),"graph_distance_m":float(distances.get(target,0))};return route
func finish(details:Dictionary,scene,walker)->void:
	details["frozen_plan"]=planned
	if is_instance_valid(scene):
		var stream=scene.get_node("Terrain")._cave_streamer;var native_ice_nodes:int=0
		for node in stream._cells.values():
			if not is_instance_valid(node):continue
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_frozen_"):native_ice_nodes+=1
		details["final_native_frozen_mesh_nodes"]=native_ice_nodes
	super.finish(details,scene,walker)
func motion_scope()->String:return "Normal saved45percent/150–700m/depth/surface Frozen controls,regional activity.85;first wet preselected Grass seed17/(9,-3),same actual basin and graph,not a favorable reroll. Full original main scene/LOD6/camera50km/four TOTAL workers/180s preload/420s motion/native1.8m/.4m/5mps/45degree/.6snap/.75drop/same-surface return. Surface→actual mouth→Default passages→continuous Frozen region→real frozen stream/lake/shore→same exit. Fixed-fps60 acceleration with explicit loading pauses and render-off movement is NOT uninterrupted FPS/art acceptance. Saved root settings/registry unchanged."
