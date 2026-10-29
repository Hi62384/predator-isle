extends RefCounted
## Retained optional side basins,not a global groundwater simulation. Their
## carved bed is separate from the calm water surface;main routes stay dry.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Surface=preload("res://scripts/caves/seepage_surface.gd")
const MAX_BASINS:int=4
static func route_clear(center:Vector3,radius:float,bed_y:float,water_y:float,region:Dictionary)->bool:
	for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
		var points:PackedVector3Array=edge.points;var clearance:float=radius+edge.half_width+2
		for i in range(points.size()-1):
			var a:Vector3=points[i];var b:Vector3=points[i+1]
			if center.x+clearance<minf(a.x,b.x) or center.x-clearance>maxf(a.x,b.x) or center.z+clearance<minf(a.z,b.z) or center.z-clearance>maxf(a.z,b.z):continue
			var ab:=Vector2(b.x-a.x,b.z-a.z);var q:=Vector2(center.x-a.x,center.z-a.z);var t:float=clampf(q.dot(ab)/maxf(ab.length_squared(),.000001),0,1);var floor_y:float=lerpf(a.y,b.y,t)
			if (q-ab*t).length()<clearance and floor_y+edge.headroom>bed_y-.5 and floor_y<water_y+1:return false
	return true
static func make(region:Dictionary,seed_id:int,density:float=.15,require_soluble_geology:bool=true)->Array:
	var basins:Array=[]
	if density<=0 or not region.get("valid",false) or (require_soluble_geology and int(region.get("geology",0)) not in [0,2,5]):return basins
	var cell:Vector2i=region.id;var rooms:Array=region.nodes+region.get("pockets",[])
	for index in range(rooms.size()):
		if basins.size()>=MAX_BASINS:break
		var room:Dictionary=rooms[index]
		if int(room.get("level",-1))<0 or Profiles.random(cell,seed_id,1800+index)>clampf(density,0,1):continue
		var radius:float=3+Profiles.random(cell,seed_id,2000+index)*2;var depth:float=1.8+Profiles.random(cell,seed_id,2100+index)*1.7;var angle:float=Profiles.random(cell,seed_id,2200+index)*TAU;var offset:float=room.chamber_radius*.7;var center:Vector3=room.point+Vector3(cos(angle)*offset,0,sin(angle)*offset);var bed_y:float=center.y-depth;var water_y:float=center.y-.4
		if not route_clear(center,radius,bed_y,water_y,region):continue
		var overlaps:bool=false
		for previous:Dictionary in basins:
			if Vector2(center.x-previous.center.x,center.z-previous.center.z).length()<radius+previous.radius+2 and absf(water_y-previous.water_y)<depth+2:overlaps=true
			if not route_clear(center,radius,bed_y,water_y,{"edges":previous.get("stream_edges",[])}):overlaps=true
		if overlaps:continue
		var offset_lobe:=Vector3(cos(angle+.8),0,sin(angle+.8))*radius*.3
		basins.append({"id":str(room.id)+":seepage","center":center,"radius":radius,"water_radius":radius*.8,"water_y":water_y,"bed_y":bed_y,"depth":depth,"bed":{"id":str(room.id)+":basin-bed","point":Vector3(center.x,bed_y,center.z),"level":room.level,"chamber_radius":radius*.85,"chamber_height":depth+1.5},"bed_lobes":[{"id":str(room.id)+":basin-lobe","point":Vector3(center.x,bed_y+.15,center.z)+offset_lobe,"level":room.level,"chamber_radius":radius*.65,"chamber_height":depth+1.5}]})
		# A short geological feeder arcs around the same chamber margin.
		# Never cut a stream across the protected dry chamber neck or route.
		if Profiles.random(cell,seed_id,2300+index)<.4:
			var points:=PackedVector3Array();var admitted:bool=true;var turn:float=.8*(1 if Profiles.random(cell,seed_id,2400+index)<.5 else -1)
			for station in range(17):
				var t:float=float(station)/16;var yaw:float=angle+turn*(1-t);var point:Vector3=room.point+Vector3(cos(yaw)*offset,lerpf(-1.2,-depth,t),sin(yaw)*offset)
				if not route_clear(point,1.5,point.y,water_y+.1,region):admitted=false;break
				for previous:Dictionary in basins.slice(0,basins.size()-1):
					if Vector2(point.x-previous.center.x,point.z-previous.center.z).length()<1.5+previous.radius+2 and absf(water_y-previous.water_y)<depth+2:admitted=false;break
					if not route_clear(point,1.5,point.y,water_y+.1,{"edges":previous.get("stream_edges",[])}):admitted=false;break
				if not admitted:break
				points.append(point)
			if admitted:basins[-1]["stream_points"]=points;basins[-1]["stream_edges"]=[{"from":str(room.id)+":seep","to":basins[-1].id,"points":points,"half_width":1.5,"headroom":depth+1.5,"entrance":false}]
	return basins
static func water_arrays(basin:Dictionary,origin:Vector3=Vector3.ZERO)->Array:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var count:int=48;var center:Vector3=Vector3(basin.center.x,basin.water_y,basin.center.z)-origin
	for i in range(count):
		var a:float=i*TAU/count;var b:float=(i+1)*TAU/count
		for p:Vector3 in [center,center+Vector3(cos(a)*basin.water_radius,0,sin(a)*basin.water_radius),center+Vector3(cos(b)*basin.water_radius,0,sin(b)*basin.water_radius)]:vertices.append(p);normals.append(Vector3.UP);colors.append(Color(.07,.13,.14,1))
	var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_COLOR]=colors;return result
static func surface_outline(basin:Dictionary,field)->PackedVector3Array:
	# Follow the ACTUAL joined bed at its retained water level. A smaller
	# decorative disk leaves an impossible dry annulus below that same level.
	var center:=Vector3(basin.center.x,basin.water_y,basin.center.z);var result:=PackedVector3Array()
	if field.sample(center)>=-.015:return result
	for i in range(48):
		var direction:=Vector3(cos(i*TAU/48),0,sin(i*TAU/48));var low:float=0;var high:float=basin.radius*1.25
		if field.sample(center+direction*high)<0:return PackedVector3Array()
		for station in range(14):
			var mid:float=(low+high)*.5
			if field.sample(center+direction*mid)<-.035:low=mid
			else:high=mid
		result.append(center+direction*low)
	return result
static func water_cell(regions:Array,field,key:Vector3i,fluid_kind:String="water")->Dictionary:
	# A pool has exactly one half-open owner cell. Numeric worker data only;
	# every visible vertex must have real carved air and a measured solid bed.
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var ids:Array[String]=[];var rejected:Array[String]=[];var rejection_reasons:Dictionary={};var origin:Vector3=Vector3(key)*64;var channels:int=0
	for region:Dictionary in regions:
		for basin:Dictionary in region.get("pools",[]):
			if str(basin.get("fluid_kind","water"))!=fluid_kind:continue
			var center:=Vector3(basin.center.x,basin.water_y,basin.center.z)
			if field.cell(center)!=key:continue
			var patch:Dictionary=Surface.build(basin,field,int(region.get("cross_section_style",0)))
			if not patch.valid or patch.arrays.is_empty():rejected.append(basin.id);rejection_reasons[basin.id]=patch.get("reason","Empty clipped water patch");continue
			ids.append(basin.id)
			if basin.has("stream_points"):channels+=1
			for point:Vector3 in patch.arrays[Mesh.ARRAY_VERTEX]:vertices.append(point-origin)
			normals.append_array(patch.arrays[Mesh.ARRAY_NORMAL]);colors.append_array(patch.arrays[Mesh.ARRAY_COLOR]);uv.append_array(patch.arrays[Mesh.ARRAY_TEX_UV]);uv2.append_array(patch.arrays[Mesh.ARRAY_TEX_UV2])
	var result:Array=[]
	if not vertices.is_empty():result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_COLOR]=colors;result[Mesh.ARRAY_TEX_UV]=uv;result[Mesh.ARRAY_TEX_UV2]=uv2
	return {"arrays":result,"ids":ids,"rejected":rejected,"channels":channels,"rejection_reasons":rejection_reasons}
