extends RefCounted
## One bounded connected water patch per basin,including optional short
## feeder channels. Triangle clipping follows real bed air at the retained
## water level;no overlapping decorative pool/stream planes.
const Field=preload("res://scripts/caves/field.gd")
const STEP:float=.5
const MAX_VERTICES:int=30000
static func water_point(pool:Dictionary,p:Vector2)->Vector3:
	var surface:float=pool.water_y;var points:PackedVector3Array=pool.get("stream_points",PackedVector3Array());var best:float=INF;var progress:float=1
	for i in range(points.size()-1):
		var a:=Vector2(points[i].x,points[i].z);var b:=Vector2(points[i+1].x,points[i+1].z);var ab:Vector2=b-a;var t:float=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.000001),0,1);var distance:float=p.distance_squared_to(a+ab*t)
		if distance<best:best=distance;progress=(float(i)+t)/(points.size()-1)
	if not points.is_empty():surface+=.10*(1-progress)*smoothstep(pool.radius,pool.radius+2,p.distance_to(Vector2(pool.center.x,pool.center.z)))
	return Vector3(p.x,surface,p.y)
static func clip_triangle(points:Array[Vector3],values:Array[float],local,field)->Array[Vector3]:
	var result:Array[Vector3]=[]
	for i in range(3):
		var previous:int=(i+2)%3;var a:Vector3=points[previous];var b:Vector3=points[i];var va:float=values[previous]+.035;var vb:float=values[i]+.035;var inside_a:bool=va<0;var inside_b:bool=vb<0
		if inside_a!=inside_b:
			# Nonlinear joined-bed shoulders cannot be clipped by interpolating
			# coarse scalar samples alone. Refine the actual field intersection
			# and retain the INSIDE endpoint of the original35mm margin.
			var low:Vector3=a;var high:Vector3=b
			for iteration in range(10):
				var mid:Vector3=(low+high)*.5;var inside:bool=maxf(local.sample(mid),field.sample(mid))<-.035
				if inside==inside_a:low=mid
				else:high=mid
			result.append(low if inside_a else high)
		if inside_b:result.append(b)
	return result
static func build(pool:Dictionary,field,style:int=0)->Dictionary:
	var local=Field.new();local.maximum_depth=field.maximum_depth;local.minimum_roof=field.minimum_roof;var nodes:Array=[pool.bed]+pool.get("bed_lobes",[]);var edges:Array=pool.get("stream_edges",[])
	if not local.compile([{"valid":true,"nodes":nodes,"edges":edges,"cross_section_style":style}],field.height):return {"valid":false,"reason":"Invalid local seepage bed"}
	var low:=Vector2(pool.center.x-pool.radius-1,pool.center.z-pool.radius-1);var high:Vector2=low+Vector2.ONE*(pool.radius+1)*2;var path:PackedVector3Array=pool.get("stream_points",PackedVector3Array())
	for point:Vector3 in path:low=low.min(Vector2(point.x,point.z)-Vector2.ONE*2.5);high=high.max(Vector2(point.x,point.z)+Vector2.ONE*2.5)
	var first:=Vector2i(floori(low.x/STEP),floori(low.y/STEP));var last:=Vector2i(ceili(high.x/STEP),ceili(high.y/STEP));var width:int=last.x-first.x+1;var height:int=last.y-first.y+1
	if width<2 or height<2 or width*height>8192:return {"valid":false,"reason":"Seepage surface exceeds bounded sampling domain"}
	var samples:=PackedFloat32Array();var positions:=PackedVector3Array();samples.resize(width*height);positions.resize(width*height)
	for z in range(height):
		for x in range(width):
			var p:Vector3=water_point(pool,Vector2(first+Vector2i(x,z))*STEP);var index:int=x+z*width;positions[index]=p;samples[index]=maxf(local.sample(p),field.sample(p))
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var measured:Dictionary={}
	for z in range(height-1):
		for x in range(width-1):
			var a:int=x+z*width;var b:int=a+1;var c:int=a+width;var d:int=c+1
			for indices:Vector3i in [Vector3i(a,b,c),Vector3i(c,b,d)]:
				var clipped:Array[Vector3]=clip_triangle([positions[indices.x],positions[indices.y],positions[indices.z]],[samples[indices.x],samples[indices.y],samples[indices.z]],local,field)
				for triangle in range(1,clipped.size()-1):
					var triangle_points:Array[Vector3]=[clipped[0],clipped[triangle],clipped[triangle+1]]
					if (triangle_points[2]-triangle_points[0]).cross(triangle_points[1]-triangle_points[0]).length_squared()<.000000000001:continue
					for point:Vector3 in triangle_points:
						if vertices.size()>=MAX_VERTICES:return {"valid":false,"reason":"Seepage surface exceeds vertex bound"}
						if not measured.has(point):
							var bottom:=Vector3(point.x,pool.bed_y-2,point.z);var top:Vector3=point
							if field.sample(top)>=-.01 or field.sample(bottom)<=0:return {"valid":false,"reason":"Seepage vertex has no measured air/solid bed at%s air=%f bed=%f"%[str(point),field.sample(top),field.sample(bottom)]}
							for iteration in range(14):
								var mid:Vector3=(bottom+top)*.5
								if field.sample(mid)>=0:bottom=mid
								else:top=mid
							var flow:float=0;var along:float=0;var angle:float=0;var closest:float=INF
							for i in range(path.size()-1):
								var p0:=Vector2(path[i].x,path[i].z);var p1:=Vector2(path[i+1].x,path[i+1].z);var ab:Vector2=p1-p0;var q:=Vector2(point.x,point.z);var t:float=clampf((q-p0).dot(ab)/maxf(ab.length_squared(),.000001),0,1);var distance:float=q.distance_squared_to(p0+ab*t)
								if distance<closest:closest=distance;angle=fposmod(ab.angle(),TAU);along=(float(i)+t)*path[0].distance_to(path[-1])/maxi(1,path.size()-1);flow=smoothstep(pool.radius*.7,pool.radius+1,q.distance_to(Vector2(pool.center.x,pool.center.z)))
							measured[point]={"bed":(bottom.y+top.y)*.5,"flow":flow,"along":along,"angle":angle}
						var payload:Dictionary=measured[point];vertices.append(point);normals.append(Vector3.UP);colors.append(Color(.08,0,1,payload.flow));uv.append(Vector2(payload.bed,payload.along));uv2.append(Vector2(payload.angle,-1))
	var arrays:Array=[]
	if not vertices.is_empty():arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2
	return {"valid":true,"arrays":arrays,"sample_count":width*height,"measured_vertices":measured.size()}
