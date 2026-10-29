extends RefCounted
## Insect excavation extension of the SAME constrained graph and implicit
## volume. No new engine,props,eggs,creatures or disconnected room meshes.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Hive=preload("res://scripts/caves/hive_network.gd")
var _hive
var builder
var configuration
var _graph:WeakRef
var network:
	get:return _graph.get_ref() if _graph!=null else null
func configure(owner,caves,graph)->void:builder=owner;configuration=caves;_graph=weakref(graph);_hive=Hive.new();_hive.configure(owner,caves,graph)
func context(cell:Vector2i)->Dictionary:
	var sampler=builder._extras[6]
	if not configuration.insect_networks or sampler==null or not sampler.settings.caves_enabled:return _hive.context(cell)
	var center:Vector2=(Vector2(cell)+Vector2(.4+.2*network.random(cell,1),.4+.2*network.random(cell,2)))*1536
	builder._biome_weights(center.x,center.y)
	if builder._extra_weights[6]<.65:return _hive.context(cell)
	var colony:Dictionary=sampler.nearby(center,2100*sampler.settings.feature_scale)
	return {"family":6,"render_style":6,"colony_id":colony.id,"surface_center":colony.position,"half_width":network.half_width*1.25,"headroom":minf(18,network.headroom*1.25),"flat_radius":36.0}
func room_fits(room:Dictionary)->bool:
	for z in range(-2,3):
		for x in range(-2,3):
			if Vector2(x,z).length()>2.1:continue
			var surface:float=builder._get_height(room.point.x+x*room.chamber_radius*.5,room.point.z+z*room.chamber_radius*.5);var depth:float=surface-room.point.y
			if not is_finite(depth) or depth>configuration.maximum_depth_metres-4 or depth<room.chamber_height+configuration.minimum_rock_cover_metres+4:return false
	return true
func decorate(region:Dictionary,description:Dictionary)->Dictionary:
	if description.get("family",-1)==7:return _hive.decorate(region,description)
	if description.get("family",-1)!=6 or not region.get("valid",false):return region
	region["cave_family"]=6;region["geology"]=6;region["render_style"]=6;region["cross_section_style"]=0;region["colony_id"]=description.colony_id;region["surface_colony_center"]=description.surface_center;region["construction"]="excavated_compacted_earth";var enlarged:int=0
	for index in range(1,region.nodes.size()):
		var node:Dictionary=region.nodes[index];var major:bool=(index-1)%4==0;var candidate:Dictionary=node.duplicate();candidate.chamber_radius=26 if major else 20;candidate.chamber_height=24 if major else 18
		if room_fits(candidate) and Profiles.compatible(candidate.point,candidate.chamber_radius,candidate.chamber_height,region,[]):node.chamber_radius=candidate.chamber_radius;node.chamber_height=candidate.chamber_height;enlarged+=int(major)
		region.nodes[index]["excavation_role"]="major_chamber" if major else "secondary_chamber"
	if region.nodes.size()>5:region["underground_colony_center"]=region.nodes[5].point
	else:region["underground_colony_center"]=region.nodes[1].point
	var branches:int=0;var original_count:int=region.nodes.size()
	for parent_index:int in [5,9]:
		if parent_index>=original_count:continue
		var parent:Dictionary=region.nodes[parent_index]
		for attempt in range(8):
			var angle:float=network.random(region.id,3100+parent_index)*TAU+attempt*TAU/8;var p:Vector3=parent.point+Vector3(cos(angle),0,sin(angle))*72;var child:Dictionary={"id":str(parent.id)+":satellite","point":p,"level":parent.level,"chamber_radius":14.0,"chamber_height":14.0,"excavation_role":"satellite_chamber"}
			if not room_fits(child) or not Profiles.compatible(p,14,14,region,[]):continue
			var width:float=network.half_width;var height:float=network.headroom;network.half_width=configuration.main_route_width_metres*.5;network.headroom=configuration.main_route_height_metres;var controls:=PackedVector2Array([Vector2(parent.point.x,parent.point.z),Vector2(p.x,p.z)]);var edge:Dictionary=network.route(parent,child,controls);network.half_width=width;network.headroom=height
			if edge.is_empty():continue
			var protected:Array=region.edges+Profiles.protected_edges(region.nodes)
			if not network.supported_join(edge,protected):continue
			edge["excavation_role"]="secondary_passage";region.nodes.append(child);region.edges.append(edge);branches+=1;break
	region["major_excavation_chambers"]=enlarged;region["satellite_passages"]=branches;return region
