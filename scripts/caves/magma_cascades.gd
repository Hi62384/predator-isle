extends RefCounted
## Rare finite molten films on an EXISTING measured rock wall and a short
## exposed fall into actual clipped retained lava. No excavation/fluid solver.
const Field=preload("res://scripts/caves/field.gd")
const Shapes=preload("res://scripts/caves/formations.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Surface=preload("res://scripts/caves/seepage_surface.gd")
static func backing_distance(field,point:Vector3,axis:Vector3)->float:
	# Find nearby solid contact. Sampling only a distant endpoint can pass
	# THROUGH a real thin rock lip and incorrectly call the attached film free.
	for distance:float in [.1,.15,.2,.25,.3]:
		if field.sample(point-axis*distance)>=.04:return distance
	return INF
static func inside_patch(point:Vector3,vertices:PackedVector3Array)->bool:
	var p:=Vector2(point.x,point.z)
	for i in range(0,vertices.size(),3):
		var a:=Vector2(vertices[i].x,vertices[i].z);var b:=Vector2(vertices[i+1].x,vertices[i+1].z);var c:=Vector2(vertices[i+2].x,vertices[i+2].z)
		var x:float=(b-a).cross(p-a);var y:float=(c-b).cross(p-b);var z:float=(a-c).cross(p-c)
		if minf(x,minf(y,z))>=-.00001 or maxf(x,maxf(y,z))<=.00001:return true
	return false
static func prepare(region:Dictionary,height:Callable,seed_id:int,settings:Dictionary,maximum_depth:float,minimum_roof:float,context)->Dictionary:
	if not settings.get("molten_cascades",false) or context==null or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var eligible:Array[int]=[]
	for index in range(region.get("pools",[]).size()):
		var pool:Dictionary=region.pools[index]
		if pool.get("fluid_kind","")=="magma" and not pool.get("magma_large_lake",false) and not pool.has("molten_cascade") and Regions.random(str(pool.id),seed_id,"magma/molten_cascade")<float(settings.get("molten_cascade_chance",.06)):eligible.append(index)
	# Most regions are dormant. Do not compile another query field for them.
	if eligible.is_empty():return region
	var field=Field.new();field.maximum_depth=maximum_depth;field.minimum_roof=minimum_roof
	if not field.compile([region],height,[],region.get("cave_biome_regions",{})):return region
	var shapes=Shapes.new()
	for index:int in eligible:
		var pool:Dictionary=region.pools[index]
		var parent_id:String=str(pool.id).trim_suffix(":seepage");var parent:Dictionary={}
		for room:Dictionary in region.nodes+region.get("pockets",[]):
			if str(room.id)==parent_id:parent=room;break
		if parent.is_empty():continue
		var radial:Vector3=(pool.center-parent.point)*Vector3(1,0,1)
		if radial.length_squared()<1:continue
		radial=radial.normalized();var tangent:Vector3=radial.cross(Vector3.UP);var rise:float=5+Regions.random(str(pool.id),seed_id,"magma/cascade_head")*3;var width:float=.24+Regions.random(str(pool.id),seed_id,"magma/cascade_width")*.25
		var patch:Dictionary=Surface.build(pool,field,int(region.get("cross_section_style",0)))
		if not patch.valid or patch.arrays.is_empty():continue
		var rows:Array=[];var normals:Array=[];var valid:bool=true;var low:=Vector3.INF;var high:=Vector3(-INF,-INF,-INF);var lip:=PackedVector3Array();var lip_height:float=0
		for row in range(25):
			var y:float=pool.water_y+.03+rise*(1-float(row)/24);var points:=PackedVector3Array();var axes:=PackedVector3Array()
			if row>0 and y<=pool.water_y+2.5:
				# The bed/room union may expose a thin undercut lip. Molten
				# fluid leaves that supported lip and falls through AIR, never
				# masquerading as attached rock across the undercut.
				if lip.is_empty():lip=rows[-1].duplicate();lip_height=lip[0].y
				for side in range(3):
					var point:Vector3=lip[side]-Vector3.UP*(lip_height-y)-radial*minf(1.4,(lip_height-y)*2.8);var witness:Dictionary=context.sample(point)
					if field.sample(point)>-.03 or float(witness.heat)<.5 or str(witness.get("id",""))!=str(pool.thermal_source) or (row==24 and not inside_patch(point,patch.arrays[Mesh.ARRAY_VERTEX])):valid=false;break
					points.append(point);axes.append(-radial);low=low.min(point);high=high.max(point)
				if not valid:break
				rows.append(points);normals.append(axes);continue
			for side:int in [-1,0,1]:
				var start:=Vector3(pool.center.x,y,pool.center.z)+tangent*side*width;var previous:Vector3=start;var wall:=Vector3.INF
				if field.sample(start)>=-.05:valid=false;break
				for step in range(1,ceili((parent.chamber_radius+12)*2)+1):
					var point:Vector3=start+radial*float(step)*.5
					# A basin lobe can leave a thin inner wall before its outer
					# boundary. Follow the OUTERMOST backed air-to-rock crossing.
					if field.sample(point)>=0 and field.sample(previous)<0:
						var boundary:Vector3=shapes.boundary(field,previous,point);var backed:bool=true
						for distance:float in [.25,.5,.75,1.0]:
							if field.sample(boundary+radial*distance)<.04:backed=false;break
						if backed:wall=boundary
					previous=point
				if not wall.is_finite():valid=false;break
				var axis:Vector3=field.normal(wall);var point:Vector3=wall-radial*.08
				var source:Dictionary=context.sample(point)
				if axis.dot(-radial)<.2 or field.sample(point)>-.04 or not is_finite(backing_distance(field,point,axis)) or not is_finite(backing_distance(field,point,field.normal(point))) or float(source.heat)<.5 or str(source.get("id",""))!=str(pool.thermal_source):valid=false;break
				if row==24 and not inside_patch(point,patch.arrays[Mesh.ARRAY_VERTEX]):valid=false;break
				points.append(point);axes.append(axis);low=low.min(point);high=high.max(point)
			if not valid:break
			rows.append(points);normals.append(axes)
		if not valid or rows.size()!=25 or shapes.protected(field,(low+high)*.5,Vector2(high.x-low.x,high.z-low.z).length()*.5,low.y,high.y):continue
		var vertices:=PackedVector3Array();var surface_normals:=PackedVector3Array()
		for row in range(24):
			for side in range(2):
				for triangle:Array in [[rows[row][side],rows[row+1][side],rows[row+1][side+1]],[rows[row][side],rows[row+1][side+1],rows[row][side+1]]]:
					var n:Vector3=(triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
					if n.dot(normals[row][side])<0:triangle.reverse();n=-n
					if n.length_squared()<.9:valid=false;break
					for point:Vector3 in triangle:vertices.append(point);surface_normals.append(n)
		if not valid:continue
		# Whole exposed edges, not only control stations, must stay backed by
		# solid host and supported by the same modeled heat source.
		for i in range(0,vertices.size(),3):
			for pair:Vector2i in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
				var point:Vector3=(vertices[i+pair.x]+vertices[i+pair.y])*.5;var axis:Vector3=field.normal(point);var source:Dictionary=context.sample(point)
				if field.sample(point)>-.03 or (point.y>lip_height+.01 and not is_finite(backing_distance(field,point,axis))) or float(source.heat)<.5 or str(source.get("id",""))!=str(pool.thermal_source):valid=false;break
		if not valid:continue
		var result:Dictionary=region.duplicate(true);result.pools[index]["molten_cascade"]={"vertices":vertices,"normals":surface_normals,"bounds":AABB(low,high-low),"thermal_source":pool.thermal_source,"source_kind":pool.get("heat_source_kind","explicit_diagnostic_intrusion"),"rise":rise,"width":width*2,"backing_offset":.08,"maximum_contact_distance":.3,"supported_lip_height":lip_height,"free_fall_height":lip_height-pool.water_y,"clipped_pool_id":pool.id};return result
	return region
static func append_to(patch:Dictionary,regions:Array,key:Vector3i)->Dictionary:
	var selected:Array=[]
	for region:Dictionary in regions:
		for pool:Dictionary in region.get("pools",[]):
			if pool.has("molten_cascade") and patch.ids.has(pool.id) and Vector3i(floori(pool.center.x/64),floori(pool.water_y/64),floori(pool.center.z/64))==key:selected.append(pool)
	if selected.is_empty():return patch
	var origin:=Vector3(key)*64;var arrays:Array=patch.arrays.duplicate(true);var count:int=0
	for pool:Dictionary in selected:
		var cascade:Dictionary=pool.molten_cascade
		for i in range(cascade.vertices.size()):
			arrays[Mesh.ARRAY_VERTEX].append(cascade.vertices[i]-origin);arrays[Mesh.ARRAY_NORMAL].append(cascade.normals[i]);arrays[Mesh.ARRAY_COLOR].append(Color(1,1,1,1));arrays[Mesh.ARRAY_TEX_UV].append(Vector2.ZERO);arrays[Mesh.ARRAY_TEX_UV2].append(Vector2(PI*.5,0))
		count+=1
	var result:Dictionary=patch.duplicate();result.arrays=arrays;result["molten_cascades"]=count;return result
