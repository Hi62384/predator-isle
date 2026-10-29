extends RefCounted
## Worker-local normalized heat suitability:strict retained surface-lava
## witnesses,plus a separately enabled explicit active-centre intrusion model.
## Source kinds remain distinct. Neither is Kelvin,a normal geothermal
## gradient,depth-only lava or a physical heat-transfer simulation.
const Liquid=preload("res://scripts/retained_liquid_geometry.gd")
const MAX_SOURCES:int=32
const MAX_POINTS:int=512
const MAX_REGION_SOURCES:int=64
var enabled:bool=true
## Explicit modeled intrusive body beneath a canonical active volcanic
## centre. Separate from the retained-surface-lava witness mechanism.
var geological_intrusions:bool=false:
	set(value):
		geological_intrusions=value;_points.clear();_sources.clear()
var _owner:WeakRef
var _sources:Dictionary={}
var _points:Dictionary={}
func configure(builder)->void:
	_owner=weakref(builder);_sources.clear();_points.clear()
func source_descriptor(builder,sampler,descriptor:Dictionary)->Dictionary:
	var id:String=str(descriptor.id)
	if _sources.has(id):return _sources[id]
	var result:Dictionary={};var center:Vector2=descriptor.position
	if descriptor.chance<sampler.settings.active_frequency:
		var regional:float=sampler.region(center)
		if regional<=2.65:
			builder._biome_weights(center.x,center.y)
			if builder._extra_weights[2]>=.95 and builder._island_mask(center.x,center.y)>=.1:
				var radius:float=descriptor.radius*(.85 if regional>1.6 else .38);var measurement:Dictionary=Liquid.measure(builder,center,radius)
				if measurement.retained:result={"id":id,"center":center,"radius":radius,"surface_y":measurement.surface_y,"bed_y":measurement.bed_y,"rim_y":measurement.rim_y,"age":descriptor.age,"kind":"retained_surface_crater_vertical_intrusion","source_evidence":"Same canonical terrain owner,island,active,regional,32rim,level and clipped-grid conditions as surface renderer;not eligibility hash alone."}
	if _sources.size()>=MAX_SOURCES:_sources.erase(_sources.keys()[0])
	_sources[id]=result;return result
func in_rendered_footprint(builder,point:Vector2,source:Dictionary)->bool:
	var step:float=source.radius/12.0;var local:Vector2=(point-source.center)/step;var x:int=floori(local.x);var z:int=floori(local.y)
	if x< -12 or x>=12 or z< -12 or z>=12 or Vector2(x+.5,z+.5).length()>11.4:return false
	if builder._get_height(point.x,point.y)>=float(source.surface_y)-.25:return false
	var corners:Array[Vector3]=[]
	for offset:Vector2 in [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
		var p:Vector2=source.center+offset*step;corners.append(Vector3(p.x,builder._get_height(p.x,p.y),p.y))
	for indices:Array in [[0,1,2],[0,2,3]]:
		var polygon:PackedVector3Array=Liquid.clipped_polygon(builder,corners[indices[0]],corners[indices[1]],corners[indices[2]],source.surface_y);var planar:=PackedVector2Array()
		for p:Vector3 in polygon:planar.append(Vector2(p.x,p.z))
		if planar.size()>=3 and Geometry2D.is_point_in_polygon(point,planar):return true
	return false
func intrusion_descriptor(builder,sampler,descriptor:Dictionary)->Dictionary:
	var key:String="intrusion/"+str(descriptor.id)
	if _sources.has(key):return _sources[key]
	var result:Dictionary={};var center:Vector2=descriptor.position
	if geological_intrusions and descriptor.chance<sampler.settings.active_frequency and sampler.region(center)<=2.65:
		builder._biome_weights(center.x,center.y)
		if builder._extra_weights[2]>=.95 and builder._island_mask(center.x,center.y)>=.1:
			var surface:float=builder._get_height(center.x,center.y);var ceiling:float=surface-64.0
			if is_finite(surface) and surface>builder.water_level+2:
				result={"id":str(descriptor.id)+"/intrusion","center":center,"radius":descriptor.radius*.38,"surface_y":ceiling,"bed_y":ceiling-320.0,"age":descriptor.age,"kind":"explicit_modeled_active_volcanic_intrusion","source_evidence":"Explicit idealized intrusive body64–864m below a canonical normally active volcanic centre;normal source hash,region,owner and island required. Not a retained surface pool,measured temperature or depth-only geothermal gradient."}
	if _sources.size()>=MAX_SOURCES:_sources.erase(_sources.keys()[0])
	_sources[key]=result;return result
func witness(point:Vector2)->Dictionary:
	if not enabled or not point.is_finite() or _owner==null:return {}
	var builder=_owner.get_ref()
	if builder==null or builder._extras.size()<=2 or builder._extras[2]==null:return {}
	var sampler=builder._extras[2]
	if not sampler.settings.special_liquids_enabled:return {}
	if _points.has(point):return _points[point]
	var span:float=7200*sampler.settings.feature_scale;var cell:=Vector2i(floori(point.x/span),floori(point.y/span));var result:Dictionary={};var candidates:Array=[]
	for z in range(-1,2):
		for x in range(-1,2):
			var descriptor:Dictionary=sampler.descriptor(cell+Vector2i(x,z),span)
			if descriptor.chance>=sampler.settings.active_frequency or point.distance_squared_to(descriptor.position)>pow(descriptor.radius*.85*1.02,2):continue
			candidates.append(descriptor)
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id))
	for descriptor:Dictionary in candidates:
		var source:Dictionary=source_descriptor(builder,sampler,descriptor)
		if not source.is_empty() and in_rendered_footprint(builder,point,source):
			result=source.duplicate();result["surface_witness"]=Vector3(point.x,source.surface_y,point.y);break
		var intrusive:Dictionary=intrusion_descriptor(builder,sampler,descriptor)
		if intrusive.is_empty() or point.distance_to(intrusive.center)>=intrusive.radius:continue
		result=intrusive.duplicate();result["surface_witness"]=Vector3(point.x,intrusive.surface_y,point.y);break
	if _points.size()>=MAX_POINTS:_points.erase(_points.keys()[0])
	_points[point]=result;return result
func sample(point:Vector3)->Dictionary:
	if not point.is_finite():return {"heat":0.0}
	var source:Dictionary=witness(Vector2(point.x,point.z))
	if source.is_empty():return {"heat":0.0}
	var below_source:float=float(source.surface_y)-point.y
	if below_source<0 or below_source>=800:return {"heat":0.0}
	var result:Dictionary=source.duplicate();result["heat"]=1.0-smoothstep(128.0,800.0,below_source)
	if str(source.kind)=="explicit_modeled_active_volcanic_intrusion":result.heat*=1.0-smoothstep(float(source.radius)*.55,float(source.radius),Vector2(point.x,point.z).distance_to(source.center))
	result["distance_below_source_m"]=below_source;return result
func cache_counts()->Vector2i:return Vector2i(_sources.size(),_points.size())
func annotate_region(region:Dictionary)->Dictionary:
	if not enabled or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	if _owner==null:return region
	var builder=_owner.get_ref()
	if builder==null or builder._extras.size()<=2 or builder._extras[2]==null or not builder._extras[2].settings.special_liquids_enabled:return region
	var rooms:Array=region.get("nodes",[])+region.get("pockets",[])
	for pool:Dictionary in region.get("pools",[]):rooms.append_array(pool.get("bank_lobes",[]))
	rooms.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id))
	var sources:Array=[];var seen:Dictionary={}
	for room:Dictionary in rooms:
		if sources.size()>=MAX_REGION_SOURCES:break
		if int(room.get("level",-1))<0 or seen.has(str(room.id)):continue
		seen[str(room.id)]=true;var point:Vector3=room.point;var source:Dictionary=sample(point+Vector3.UP*minf(8,float(room.chamber_height)*.3))
		if float(source.heat)<=.01:continue
		sources.append({"id":str(room.id)+"/intrusive_heat","point":point,"radius":minf(96,float(room.chamber_radius)+12),"height":minf(96,float(room.chamber_height)+8),"heat":float(source.heat),"surface_source":source.id,"surface_witness":source.surface_witness,"kind":source.kind})
	# Real hot intersections may lie between room anchors. Sample existing
	# solved passages,not imaginary depth-only sources or new cave routes.
	var edges:Array=region.get("edges",[])+region.get("pocket_passages",[])
	edges.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.from)+"/"+str(a.to)<str(b.from)+"/"+str(b.to))
	for edge:Dictionary in edges:
		if sources.size()>=MAX_REGION_SOURCES:break
		var points:PackedVector3Array=edge.points;var distance:float=0;var next_station:float=0;var station:int=0
		for index in range(1,points.size()):
			var a:Vector3=points[index-1];var b:Vector3=points[index];var length:float=a.distance_to(b)
			while next_station<=distance+length and sources.size()<MAX_REGION_SOURCES:
				var point:Vector3=a.lerp(b,clampf((next_station-distance)/maxf(length,.000001),0,1));var source:Dictionary=sample(point+Vector3.UP*minf(4,edge.headroom*.5))
				if float(source.heat)>.01:sources.append({"id":str(edge.from)+"/"+str(edge.to)+"/intrusive_heat/"+str(station),"point":point,"radius":minf(32,edge.half_width+16),"height":minf(96,edge.headroom+8),"heat":float(source.heat),"surface_source":source.id,"surface_witness":source.surface_witness,"kind":source.kind})
				next_station+=32;station+=1
			distance+=length
	if sources.is_empty():return region
	var result:Dictionary=region.duplicate();result["cave_thermal_sources"]=sources;return result
