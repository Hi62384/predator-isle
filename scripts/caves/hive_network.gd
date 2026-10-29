extends RefCounted
## Organic extension of the existing solved graph/implicit volume. The
## surface nerve identity remains the source;no independent cave engine.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
var builder
var configuration
var _graph:WeakRef
var network:
	get:return _graph.get_ref() if _graph!=null else null
func configure(owner,caves,graph)->void:builder=owner;configuration=caves;_graph=weakref(graph)
func context(cell:Vector2i)->Dictionary:
	var field=builder._extras[7]
	if not configuration.hive_networks or field==null or not field.settings.caves_enabled:return {}
	var center:Vector2=(Vector2(cell)+Vector2(.4+.2*network.random(cell,1),.4+.2*network.random(cell,2)))*1536;builder._biome_weights(center.x,center.y)
	if builder._extra_weights[7]<.65:return {}
	var source:Dictionary=field.network(center)
	return {"family":7,"render_style":7,"hive_id":source.id,"surface_center":source.center,"hive_region":field.region(center),"half_width":network.half_width*1.25,"headroom":minf(18,network.headroom*1.25),"flat_radius":36.0,"planning_depth_reserve":2.0}
func room_fits(room:Dictionary)->bool:
	for z in range(-2,3):
		for x in range(-2,3):
			if Vector2(x,z).length()>2.1:continue
			var surface:float=builder._get_height(room.point.x+x*room.chamber_radius*.5,room.point.z+z*room.chamber_radius*.5);var depth:float=surface-room.point.y
			if not is_finite(depth) or depth>configuration.maximum_depth_metres-4 or depth<room.chamber_height+configuration.minimum_rock_cover_metres+4:return false
	return true
func decorate(region:Dictionary,description:Dictionary)->Dictionary:
	if description.get("family",-1)!=7 or not region.get("valid",false):return region
	region["cave_family"]=7;region["geology"]=7;region["render_style"]=7;region["cross_section_style"]=7;region["hive_id"]=description.hive_id;region["surface_hive_center"]=description.surface_center;region["hive_region"]=description.hive_region;region["construction"]="assimilated_organic_volume";var enlarged:int=0
	for i in range(1,region.nodes.size()):
		var node:Dictionary=region.nodes[i];var major:bool=(i-1)%4==0;var candidate:Dictionary=node.duplicate();candidate.chamber_radius=26 if major else 22;candidate.chamber_height=26 if major else 20
		if room_fits(candidate) and Profiles.compatible(candidate.point,candidate.chamber_radius,candidate.chamber_height,region,[]):node.chamber_radius=candidate.chamber_radius;node.chamber_height=candidate.chamber_height;enlarged+=int(major)
		node["hive_role"]="primary_nerve_junction" if major else "organic_chamber"
	var core:Dictionary=region.nodes[9] if region.nodes.size()>9 else region.nodes[5 if region.nodes.size()>5 else 1];region["underground_hive_center"]=core.point;region["hive_core_node"]=core.id;region["underground_geometry"]=true
	var pockets:Array=[]
	# Unequal overlapping lobes form a folded regional organ cavity,not one
	# giant sphere or a prop blocking a dry route. Each bounded lobe stays in
	# the existing128-bin-reference feature budget and has a full dry neck.
	for lobe in range(6):
		var angle:float=network.random(region.id,4300)*TAU+lobe*TAU/6;var span:float=30+network.random(region.id,4310+lobe)*8;var room:Dictionary={"id":str(core.id)+":neural_lobe:"+str(lobe),"parent":core.id,"point":core.point+Vector3(cos(angle),0,sin(angle))*span,"level":core.level,"chamber_radius":22+network.random(region.id,4320+lobe)*3,"chamber_height":22+network.random(region.id,4330+lobe)*4,"hive_role":"folded_core_lobe"}
		if not room_fits(room) or not Profiles.compatible(room.point,room.chamber_radius,room.chamber_height,region,pockets):continue
		var clear:bool=true
		for step in range(ceili(span/2)+1):
			if not Profiles.compatible(core.point.lerp(room.point,float(step)/ceili(span/2)),4,8,region,pockets):clear=false;break
		if clear:pockets.append(room)
	region["pockets"]=pockets;region["pocket_passages"]=Profiles.passages(region,pockets);var branches:int=0;var original_count:int=region.nodes.size()
	for parent_index:int in [5,9]:
		if parent_index>=original_count:continue
		var parent:Dictionary=region.nodes[parent_index]
		for attempt in range(8):
			var angle:float=network.random(region.id,4400+parent_index)*TAU+attempt*TAU/8;var child:Dictionary={"id":str(parent.id)+":nerve_branch","point":parent.point+Vector3(cos(angle),0,sin(angle))*76,"level":parent.level,"chamber_radius":16.0,"chamber_height":16.0,"hive_role":"secondary_nerve_chamber"}
			if not room_fits(child) or not Profiles.compatible(child.point,16,16,region,pockets):continue
			var width:float=network.half_width;var height:float=network.headroom;network.half_width=configuration.main_route_width_metres*.5;network.headroom=configuration.main_route_height_metres;var edge:Dictionary=network.route(parent,child,PackedVector2Array([Vector2(parent.point.x,parent.point.z),Vector2(child.point.x,child.point.z)]));network.half_width=width;network.headroom=height
			if edge.is_empty() or not network.supported_join(edge,region.edges+Profiles.protected_edges(region.nodes+pockets)):continue
			edge["hive_role"]="secondary_nerve_conduit";region.nodes.append(child);region.edges.append(edge);branches+=1;break
	region["primary_hive_chambers"]=enlarged;region["secondary_nerve_branches"]=branches;return region
