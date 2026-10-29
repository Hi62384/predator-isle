extends "res://scripts/caves/portal_mesher.gd"
## Private uniform-grid study. Same tetrahedra/signs; refine only bracketed
## intersections near the selected lake. No extra lattice or topology changes.
var shore_center:=Vector3.ZERO
var shore_radius:float=0
var refined_edges:int=0
var original_residual:float=0
var refined_residual:float=0
var attempted_triangles:int=0
var collapsed_triangles:int=0
func emit(a:Vector3,b:Vector3,c:Vector3)->void:
	attempted_triangles+=1
	if (c-a).cross(b-a).length_squared()==0:collapsed_triangles+=1
	super.emit(a,b,c)
static func topology(arrays:Array,origin:Vector3)->Dictionary:
	var edges:Dictionary={};var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var collapsed:int=0
	for index in range(0,vertices.size(),3):
		var p:Vector3=vertices[index];var q:Vector3=vertices[index+1];var r:Vector3=vertices[index+2]
		if (q-p).cross(r-p).length_squared()==0:collapsed+=1
		for pair in [[p,q],[q,r],[r,p]]:
			var a:Vector3i=Vector3i((pair[0]*4096).round());var b:Vector3i=Vector3i((pair[1]*4096).round())
			if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):var swap:Vector3i=a;a=b;b=swap
			var key:Array=[a,b];edges[key]=int(edges.get(key,0))+1
	var interior_open:int=0;var nonmanifold:int=0;var boundary:Array=[]
	for key:Array in edges:
		if edges[key]>2:nonmanifold+=1
		elif edges[key]==1:
			var a:Vector3=Vector3(key[0])/4096;var b:Vector3=Vector3(key[1])/4096;var on_boundary:bool=false
			for axis in range(3):
				if (a[axis]==0 and b[axis]==0) or (a[axis]==64 and b[axis]==64):on_boundary=true
			if not on_boundary:interior_open+=1
			else:boundary.append([a+origin,b+origin])
	return {"collapsed":collapsed,"interior_open_edges":interior_open,"nonmanifold_edges":nonmanifold,"boundary":boundary}
func crossing(a:Vector3,b:Vector3,va:float,vb:float)->Vector3:
	var original:Vector3=super.crossing(a,b,va,vb)
	if shore_radius<=0 or Vector2(original.x-shore_center.x,original.z-shore_center.z).length()>shore_radius+4 or absf(original.y-shore_center.y)>6:return original
	if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):
		var point:Vector3=a;a=b;b=point;var value:float=va;va=vb;vb=value
	var low:Vector3=a;var high:Vector3=b;var inside:bool=va<0
	for iteration in range(12):
		var mid:Vector3=(low+high)*.5
		if (field.sample(mid)<0)==inside:low=mid
		else:high=mid
	var refined:Vector3=(((low+high)*.5)*4096).round()/4096
	refined_edges+=1;original_residual=maxf(original_residual,absf(field.sample(original)));refined_residual=maxf(refined_residual,absf(field.sample(refined)))
	return refined
