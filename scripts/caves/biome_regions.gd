extends RefCounted
## Deterministic graph geography,not a per-voxel lottery. Pure numeric results
## travel in existing worker bundles;no new worker pool or world ownership.
const Definition=preload("res://scripts/caves/biome_definition.gd")
const MAX_NODES:int=128
const MAX_EDGES:int=256
var builder
var settings:Resource
var seed_id:int=73921
var environment_provider:Callable
var geometry_provider:Callable
func configure(owner,configuration:Resource,seed_value:int)->void:builder=owner;settings=configuration;seed_id=seed_value
static func random(identity:String,seed_value:int,channel:String)->float:
	# SHA256 is stable across platforms/processes and independent of generation
	# order. Separate named channels keep chance/size/competition independent.
	var bytes:PackedByteArray=(str(seed_value)+"/"+identity+"/"+channel).sha256_buffer();var value:int=int(bytes[0])|(int(bytes[1])<<8)|(int(bytes[2])<<16)|(int(bytes[3])<<24);return float(value)/4294967296.0
static func proposal(definition:Resource,identity:String,seed_value:int)->Dictionary:
	return {"accepted":definition.enabled and random(identity,seed_value,"spawn/"+str(definition.biome_id))*100<definition.spawn_chance_percent,"extent_m":lerpf(definition.minimum_extent_metres,definition.maximum_extent_metres,random(identity,seed_value,"extent/"+str(definition.biome_id)))}
static func suitability_admitted(definition:Resource,identity:String,seed_value:int,suitability:float)->bool:
	return is_finite(suitability) and suitability>0 and random(identity,seed_value,"suitability/"+str(definition.biome_id))<clampf(suitability,0,1)
func surface_mix(point:Vector3)->Dictionary:
	var weights:Vector4=builder._biome_weights(point.x,point.z);var mix:Dictionary={"grass":weights.x,"forest":weights.y,"savanna":weights.z,"swamp":weights.w,"jungle":builder._jungle_weight,"mountain":builder._mountain_weight,"tropical":builder._tropical_weight,"badlands":builder._badlands_weight}
	for i in range(8):mix[TerrainSettings.EXTENSION_KEYS[i]]=builder._extra_weights[i]
	# Rocky Coast is a real overlay,not a seventeenth surface owner. Query its
	# canonical sampler directly;last-payload state can belong to another point
	# after height-only cache hits. Old registries with no overlay preference do
	# not even query it,and keep their previous floating-point output exactly.
	var wants_coast:bool=false
	for definition:Resource in settings.definitions:
		if definition.enabled and definition.spawn_chance_percent>0 and definition.surface_preferences.has("rocky_coast"):wants_coast=true;break
	if wants_coast and builder.has_method("_coast_payload") and builder.settings.rocky_coast_enabled and builder._coast!=null:
		var distance_hint:float=builder._island_mask(point.x,point.z)*maxf(builder.settings.island_size*.5,8)
		builder._coast.sample(point.x,point.z,0,distance_hint,true);var state:PackedFloat64Array=builder._coast.state
		var amount:float=clampf(state[2],0,1)*(1-clampf(state[19],0,1))
		if amount>0:
			for key in mix:mix[key]*=1-amount
			mix["rocky_coast"]=amount
	return mix
static func graph(region:Dictionary)->Dictionary:
	var nodes:Dictionary={};var edges:Array=[];var adjacency:Dictionary={}
	for room:Dictionary in region.nodes+region.get("pockets",[]):
		if nodes.size()>=MAX_NODES:return {}
		if nodes.has(str(room.id)):return {}
		nodes[str(room.id)]=room;adjacency[str(room.id)]=[]
	for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
		if edges.size()>=MAX_EDGES or not nodes.has(str(edge.from)) or not nodes.has(str(edge.to)):return {}
		var length_m:float=0;var points:PackedVector3Array=edge.points
		if points.size()<2:return {}
		for i in range(1,points.size()):length_m+=points[i-1].distance_to(points[i])
		if not is_finite(length_m) or length_m<0:return {}
		var index:int=edges.size();edges.append({"from":str(edge.from),"to":str(edge.to),"length":length_m});adjacency[str(edge.from)].append(index);adjacency[str(edge.to)].append(index)
	return {"nodes":nodes,"edges":edges,"adjacency":adjacency}
static func distances(topology:Dictionary,anchor:String,reach:float)->Dictionary:
	var result:Dictionary={anchor:0.0};var visited:Dictionary={}
	for iteration in range(topology.nodes.size()):
		var nearest:String="";var distance:float=INF
		var keys:Array=result.keys();keys.sort()
		for key:String in keys:
			if not visited.has(key) and float(result[key])<distance:nearest=key;distance=float(result[key])
		if nearest.is_empty() or distance>reach:break
		visited[nearest]=true
		for index:int in topology.adjacency[nearest]:
			var edge:Dictionary=topology.edges[index];var other:String=edge.to if edge.from==nearest else edge.from;var proposed:float=distance+edge.length
			# Retain endpoints just beyond the reach too:their distance is needed
			# to classify partial coverage along a long connecting passage.
			if proposed<float(result.get(other,INF)):result[other]=proposed
	var ordered:Dictionary={};var keys:Array=result.keys();keys.sort()
	for key:String in keys:ordered[key]=result[key]
	return ordered
func decorate(region:Dictionary)->Dictionary:
	if settings==null or not settings.enabled or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var topology:Dictionary=graph(region)
	if topology.is_empty():return region
	var definitions:Array=settings.definitions.duplicate();definitions.sort_custom(func(a,b)->bool:return str(a.biome_id)<str(b.biome_id));var candidates:Array=[];var anchors:Array=topology.nodes.keys();anchors.sort()
	for anchor:String in anchors:
		var room:Dictionary=topology.nodes[anchor]
		if int(room.get("level",-1))<0:continue
		var depth:float=float(builder._get_height(room.point.x,room.point.z))-room.point.y;var mix:Dictionary=surface_mix(room.point);var eligible:Array=[];var independent:Array=[];var total:float=0
		for definition:Resource in definitions:
			if not proposal(definition,anchor,seed_id).accepted:continue
			var depth_weight:float=definition.depth_preference(depth,settings.depth_bands);var surface_weight:float=Definition.preference(definition.surface_preferences,mix);var geology_weight:float=Definition.preference(definition.geological_preferences,{region.get("geology",0):1.0});var environment:float=1.0
			if environment_provider.is_valid():
				for channel:StringName in [definition.temperature_channel,definition.moisture_channel]:
					if not channel.is_empty():
						var value:float=float(environment_provider.call(channel,room.point));environment*=clampf(value,0,1) if is_finite(value) else 0.0
			var suitability:float=depth_weight*surface_weight*geology_weight*environment
			if definition.independent_suitability_admission:
				if suitability_admitted(definition,anchor,seed_id,suitability):independent.append({"definition":definition,"depth":depth_weight,"surface":surface_weight,"geology":geology_weight,"environment":environment})
				continue
			var weight:float=suitability*pow(2,definition.selection_priority)
			if weight<=0:continue
			total+=weight;eligible.append({"definition":definition,"weight":weight,"depth":depth_weight,"surface":surface_weight,"geology":geology_weight,"environment":environment})
		if not eligible.is_empty():
			var lottery:float=random(anchor,seed_id,"competition")*total;var choice:Dictionary=eligible[-1]
			for option:Dictionary in eligible:
				lottery-=option.weight
				if lottery<0:choice=option;break
			independent.push_front(choice)
		for choice:Dictionary in independent:
			var definition:Resource=choice.definition;var extent:float=proposal(definition,anchor,seed_id).extent_m;var reach:float=extent*.5
			var candidate:Dictionary={"id":anchor+"/"+str(definition.biome_id),"biome_id":str(definition.biome_id),"anchor":anchor,"point":room.point,"extent_m":extent,"reach_m":reach,"transition_m":minf(definition.transition_metres,reach),"depth_m":depth,"depth_preference":choice.depth,"surface_preference":choice.surface,"geological_preference":choice.geology,"environment_preference":choice.environment,"distances":distances(topology,anchor,reach),"debug_color":definition.debug_color}
			if definition.independent_suitability_admission:candidate["connected_growth"]=true
			candidates.append(candidate)
	region["cave_biome_regions"]={"fallback":str(settings.fallback_biome_id),"candidates":candidates,"edges":topology.edges,"depth_bands":settings.depth_bands.duplicate()}
	return geometry_provider.call(region) if geometry_provider.is_valid() else region
static func combine(regions:Array,connections:Array,fallback:String="default")->Dictionary:
	var candidates:Array=[];var edges:Array=[];var identities:Dictionary={}
	for region:Dictionary in regions:
		var assignment:Dictionary=region.get("cave_biome_regions",{})
		for candidate:Dictionary in assignment.get("candidates",[]):
			if not identities.has(candidate.id):candidates.append(candidate);identities[candidate.id]=true
		edges.append_array(assignment.get("edges",[]))
	for connection:Dictionary in connections:
		var length_m:float=0;var points:PackedVector3Array=connection.points
		for i in range(1,points.size()):length_m+=points[i-1].distance_to(points[i])
		edges.append({"from":str(connection.from),"to":str(connection.to),"length":length_m})
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id));edges.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return (str(a.from)+"/"+str(a.to))<(str(b.from)+"/"+str(b.to)))
	var grow:bool=false
	for candidate:Dictionary in candidates:
		if candidate.get("connected_growth",false):grow=true;break
	if grow:
		# Include real inter-region edges in geodesic growth. Legacy candidates
		# remain exact;only the opt-in independent regions use the combined graph.
		var topology:Dictionary={"nodes":{},"edges":edges,"adjacency":{}};var locked:Dictionary={}
		for region:Dictionary in regions:
			if region.get("cave_family",-1) in [6,7]:
				for node:Dictionary in region.get("nodes",[])+region.get("pockets",[]):locked[str(node.id)]=true
		for index in range(edges.size()):
			if locked.has(str(edges[index].from)) or locked.has(str(edges[index].to)):continue
			for id:String in [edges[index].from,edges[index].to]:
				topology.nodes[id]=true
				if not topology.adjacency.has(id):topology.adjacency[id]=[]
				topology.adjacency[id].append(index)
		for candidate:Dictionary in candidates:
			if candidate.get("connected_growth",false) and not topology.nodes.has(str(candidate.anchor)):topology.nodes[str(candidate.anchor)]=true;topology.adjacency[str(candidate.anchor)]=[]
		if topology.nodes.size()>4096 or edges.size()>8192:return {"valid":false,"fallback":fallback,"candidates":[],"edges":[]}
		for i in range(candidates.size()):
			if not candidates[i].get("connected_growth",false):continue
			var candidate:Dictionary=candidates[i].duplicate();candidate["distances"]=distances(topology,candidate.anchor,candidate.reach_m);candidates[i]=candidate
	return {"fallback":fallback,"candidates":candidates,"edges":edges}
static func along_edge(assignment:Dictionary,from_id:String,to_id:String,station:float,length_m:float)->Dictionary:
	if not is_finite(station) or not is_finite(length_m) or length_m<0:return {"primary":str(assignment.get("fallback","default")),"weights":{str(assignment.get("fallback","default")):1.0},"candidate_ids":{},"graph_distances":{}}
	station=clampf(station,0,length_m)
	var fields:Dictionary={};var nearest:Dictionary={};var winners:Dictionary={}
	for candidate:Dictionary in assignment.get("candidates",[]):
		var distance:float=minf(float(candidate.distances.get(from_id,INF))+station,float(candidate.distances.get(to_id,INF))+length_m-station)
		if distance>=candidate.reach_m:continue
		var amount:float=1-smoothstep(candidate.reach_m-candidate.transition_m,candidate.reach_m,distance);var id:String=candidate.biome_id
		if amount>float(fields.get(id,0)) or (is_equal_approx(amount,float(fields.get(id,0))) and str(candidate.id)<str(winners.get(id,"~"))):fields[id]=amount;nearest[id]=distance;winners[id]=candidate.id
	var fallback:String=str(assignment.get("fallback","default"));var maximum:float=0
	for id:String in fields:
		if id!=fallback:maximum=maxf(maximum,float(fields[id]))
	fields[fallback]=1-maximum;var total:float=0
	for value in fields.values():total+=float(value)
	var weights:Dictionary={};var ids:Array=fields.keys();ids.sort();var primary:String=fallback;var strongest:float=-1
	for id:String in ids:
		weights[id]=float(fields[id])/maxf(total,.000001)
		if weights[id]>strongest:strongest=weights[id];primary=id
	return {"primary":primary,"weights":weights,"candidate_ids":winners,"graph_distances":nearest}
static func description(assignment:Dictionary)->String:
	var counts:Dictionary={};var minimum:float=INF;var maximum:float=0
	for candidate:Dictionary in assignment.get("candidates",[]):
		counts[candidate.biome_id]=int(counts.get(candidate.biome_id,0))+1;minimum=minf(minimum,candidate.extent_m);maximum=maxf(maximum,candidate.extent_m)
	if counts.is_empty():return "Cave biome: Default fallback"
	var parts:Array[String]=[];var ids:Array=counts.keys();ids.sort()
	for id:String in ids:parts.append(id+":"+str(counts[id]))
	return "Graph biome regions %s | extent %.0f–%.0fm"%[", ".join(parts),minimum,maximum]
