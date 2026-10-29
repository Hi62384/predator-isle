extends RefCounted
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
static func prepare(chain:Dictionary,mesh:Dictionary)->void:
	var parameters:=PackedFloat32Array();var offsets:=PackedVector3Array()
	for i in mesh.vertices.size():
		parameters.append(mesh.chain_binds[i*4+1]);offsets.append(Vector3(mesh.anchors[i*4],mesh.anchors[i*4+1],mesh.anchors[i*4+2]))
	var edges:Dictionary={};var edge_ids:=PackedInt32Array();var lengths:=PackedFloat32Array()
	var normals:=PackedVector3Array();var areas:=PackedFloat32Array();var face_parameters:=PackedFloat32Array();var axes:=Frames.normals(chain.rest)
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		var n:Vector3=(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a])
		var t:float=(parameters[a]+parameters[b]+parameters[c])/3
		normals.append(Frames.frame(chain.rest,axes,parameters[a]).transposed()*n);areas.append(n.length());face_parameters.append(t)
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if edges.has(key):continue
			edges[key]=true;edge_ids.append(edge.x);edge_ids.append(edge.y);lengths.append(mesh.vertices[edge.x].distance_to(mesh.vertices[edge.y]))
	chain["qa"]={"parameters":parameters,"offsets":offsets,"edges":edge_ids,"lengths":lengths,"normals":normals,"areas":areas,"face_parameters":face_parameters,"indices":mesh.indices}
static func valid(chain:Dictionary,points:PackedVector3Array,seed:Vector3)->bool:
	if not chain.has("qa"):return true
	var qa:Dictionary=chain.qa;var axes:=Frames.normals(points,seed);var matrices:Dictionary={};var centers:Dictionary={};var vertices:=PackedVector3Array()
	for i in qa.parameters.size():
		var t:float=qa.parameters[i]
		if not matrices.has(t):matrices[t]=Frames.frame(points,axes,t);centers[t]=Frames.point(points,t)
		var vertex:Vector3=centers[t]+matrices[t]*qa.offsets[i]
		if not vertex.is_finite():return false
		vertices.append(vertex)
	for i in qa.lengths.size():
		if vertices[qa.edges[i*2]].distance_to(vertices[qa.edges[i*2+1]])>2.2*float(qa.lengths[i]):return false
	for face in qa.areas.size():
		var a:int=qa.indices[face*3];var b:int=qa.indices[face*3+1];var c:int=qa.indices[face*3+2]
		var current:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		var ratio:float=current.length()/maxf(qa.areas[face],1e-10)
		if ratio<.18 or ratio>3.2:return false
		var reference:Vector3=matrices[qa.parameters[a]]*qa.normals[face]
		if current.dot(reference)<.3*current.length()*reference.length():return false
	return true
