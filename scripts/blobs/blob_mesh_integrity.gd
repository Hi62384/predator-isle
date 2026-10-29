extends RefCounted
## Validate actual triangles, not just buffer sizes or joint targets.
static func clean(mesh:Dictionary,keep_largest:bool=false)->Dictionary:
	for pass_id in 8:
		if not collapse_tiny_edges(mesh):break
	var kept:=PackedInt32Array(); var degenerate:=0; var invalid:=0
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		if mini(a,mini(b,c))<0 or maxi(a,maxi(b,c))>=mesh.vertices.size(): invalid+=1;continue
		var x:Vector3=mesh.vertices[a];var y:Vector3=mesh.vertices[b];var z:Vector3=mesh.vertices[c]
		if not (x.is_finite() and y.is_finite() and z.is_finite()): invalid+=1;continue
		if (y-x).cross(z-x).length_squared()<1e-16: degenerate+=1;continue
		kept.append_array(PackedInt32Array([a,b,c]))
	mesh.indices=kept
	var component_report:=components(mesh)
	var omitted:=0
	if keep_largest and component_report.count>1:
		var largest:int=component_report.largest
		kept=PackedInt32Array()
		for i in range(0,mesh.indices.size(),3):
			if component_report.roots[mesh.indices[i]]==largest: kept.append_array(mesh.indices.slice(i,i+3))
		omitted=(mesh.indices.size()-kept.size())/3;mesh.indices=kept
	_compact(mesh)
	orient(mesh)
	var junctions:=repair_t_junctions(mesh)
	var repaired:=seal_small_boundaries(mesh)
	recompute_normals(mesh)
	var edges:Dictionary={};var bad_winding:=0;var boundaries:=0;var nonmanifold:=0
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if not edges.has(key): edges[key]=[]
			edges[key].append(edge.x<edge.y)
	for values:Array in edges.values():
		if values.size()==1: boundaries+=1
		elif values.size()>2: nonmanifold+=1
		elif values[0]==values[1]: bad_winding+=1
	return {"t_junctions_repaired":junctions,"boundary_triangles_added":repaired,"degenerate_removed":degenerate,"invalid_removed":invalid,"components_before":component_report.count,"isolated_triangles_removed":omitted,"boundary_edges":boundaries,"nonmanifold_edges":nonmanifold,"inconsistent_edges":bad_winding,"triangles":mesh.indices.size()/3}
static func components(mesh:Dictionary)->Dictionary:
	var parent:=PackedInt32Array();parent.resize(mesh.vertices.size())
	for i in parent.size():parent[i]=i
	for i in range(0,mesh.indices.size(),3):
		var a:=_root(parent,mesh.indices[i]);var b:=_root(parent,mesh.indices[i+1]);var c:=_root(parent,mesh.indices[i+2]);parent[b]=a;parent[c]=a
	var roots:=PackedInt32Array();roots.resize(parent.size());var counts:Dictionary={}
	for index:int in mesh.indices:
		var root:=_root(parent,index);roots[index]=root;counts[root]=int(counts.get(root,0))+1
	var largest:=-1;var size:=0
	for key:int in counts:
		if counts[key]>size:largest=key;size=counts[key]
	return {"roots":roots,"count":counts.size(),"largest":largest}
static func _root(parent:PackedInt32Array,index:int)->int:
	while parent[index]!=index:index=parent[index]
	return index
static func _compact(mesh:Dictionary)->void:
	var lookup:Dictionary={};var ids:=PackedInt32Array()
	var used:Dictionary={}
	for index:int in mesh.indices:used[index]=true
	for index in mesh.vertices.size():
		if used.has(index):lookup[index]=ids.size();ids.append(index)
	for i in mesh.indices.size():mesh.indices[i]=lookup[mesh.indices[i]]
	for key in ["vertices","normals","colors","uvs","uvs2","feature_ids","anchors","mechanics","binds","chain_binds"]:
		if not mesh.has(key):continue
		var old:Variant=mesh[key];var values:Variant=old.slice(0,0);var stride:=4 if key in ["anchors","mechanics","binds","chain_binds"] else 1
		for id:int in ids:
			for component in stride:values.append(old[id*stride+component])
		mesh[key]=values
static func recompute_normals(mesh:Dictionary)->void:
	var normals:=PackedVector3Array();normals.resize(mesh.vertices.size())
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		var n:Vector3=-(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a])
		normals[a]+=n;normals[b]+=n;normals[c]+=n
	for i in normals.size():normals[i]=normals[i].normalized()
	mesh.normals=normals
static func strain(mesh:Dictionary,posed:PackedVector3Array,expected_normals:PackedVector3Array=PackedVector3Array())->Dictionary:
	var maximum:=.0;var minimum_area:=INF;var maximum_area:=.0;var inverted:=0;var collapsed:=0;var suspects:=PackedInt32Array()
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		var old:Vector3=(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a]);var current:Vector3=(posed[b]-posed[a]).cross(posed[c]-posed[a])
		var area:float=current.length()/maxf(old.length(),1e-12);minimum_area=minf(minimum_area,area);maximum_area=maxf(maximum_area,area)
		if area<.05:collapsed+=1
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			maximum=maxf(maximum,posed[edge.x].distance_to(posed[edge.y])/maxf(mesh.vertices[edge.x].distance_to(mesh.vertices[edge.y]),1e-8))
		if not expected_normals.is_empty():
			var normal:Vector3=expected_normals[i/3] if expected_normals.size()==mesh.indices.size()/3 else expected_normals[a]+expected_normals[b]+expected_normals[c]
			if current.dot(normal)>1e-10:inverted+=1
			if current.dot(normal)>-.8*current.length()*normal.length():suspects.append(i/3)
	return {"maximum_edge_stretch":maximum,"minimum_area_ratio":minimum_area,"maximum_area_ratio":maximum_area,"inverted":inverted,"collapsed":collapsed,"suspect_faces":suspects}

static func orient(mesh:Dictionary)->void:
	var edges:Dictionary={};var adjacency:Dictionary={}
	for face in mesh.indices.size()/3:
		var a:int=mesh.indices[face*3];var b:int=mesh.indices[face*3+1];var c:int=mesh.indices[face*3+2]
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if not edges.has(key):edges[key]=[]
			edges[key].append(Vector2i(face,1 if edge.x<edge.y else 0))
	for values:Array in edges.values():
		if values.size()!=2:continue
		var a:Vector2i=values[0];var b:Vector2i=values[1];var same:=a.y==b.y
		if not adjacency.has(a.x):adjacency[a.x]=[]
		if not adjacency.has(b.x):adjacency[b.x]=[]
		adjacency[a.x].append([b.x,same]);adjacency[b.x].append([a.x,same])
	var flips:Dictionary={}
	for seed_face in mesh.indices.size()/3:
		if flips.has(seed_face):continue
		var queue:Array[int]=[seed_face];flips[seed_face]=false;var cursor:=0;var members:Array[int]=[]
		while cursor<queue.size():
			var face:int=queue[cursor];cursor+=1;members.append(face)
			for item:Array in adjacency.get(face,[]):
				var other:int=item[0]
				if not flips.has(other):flips[other]=bool(flips[face])!=bool(item[1]);queue.append(other)
		var volume:=.0
		for face:int in members:
			var a:int=mesh.indices[face*3];var b:int=mesh.indices[face*3+1];var c:int=mesh.indices[face*3+2]
			volume+=mesh.vertices[a].dot(mesh.vertices[b].cross(mesh.vertices[c]))*(-1.0 if flips[face] else 1.0)
		for face:int in members:
			if bool(flips[face])!=(volume>0):
				var value:int=mesh.indices[face*3+1];mesh.indices[face*3+1]=mesh.indices[face*3+2];mesh.indices[face*3+2]=value

static func seal_small_boundaries(mesh:Dictionary)->int:
	var edges:Dictionary={}
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if not edges.has(key):edges[key]=[]
			edges[key].append(edge)
	var following:Dictionary={}
	for values:Array in edges.values():
		if values.size()==1:following[values[0].x]=values[0].y
	var visited:Dictionary={};var added:=0
	for start:int in following:
		if visited.has(start):continue
		var loop:Array[int]=[];var vertex:=start;var perimeter:=.0
		while following.has(vertex) and not visited.has(vertex) and loop.size()<32:
			visited[vertex]=true;loop.append(vertex)
			var next:int=following[vertex];perimeter+=mesh.vertices[vertex].distance_to(mesh.vertices[next]);vertex=next
		if vertex!=start or loop.size()<3 or perimeter>.25:continue
		# These boundaries are sub-voxel extraction defects, never designed pores.
		var center:=Vector3.ZERO
		for id:int in loop:center+=mesh.vertices[id]
		center/=loop.size()
		var area:=Vector3.ZERO
		for i in loop.size():area+=(mesh.vertices[loop[i]]-center).cross(mesh.vertices[loop[(i+1)%loop.size()]]-center)
		if area.length()<1e-7:continue
		var center_index:int=mesh.vertices.size();mesh.vertices.append(center)
		for key in ["normals","colors","uvs","uvs2","feature_ids","anchors","mechanics","binds","chain_binds"]:
			if not mesh.has(key):continue
			var stride:=4 if key in ["anchors","mechanics","binds","chain_binds"] else 1
			for component in stride:mesh[key].append(mesh[key][loop[0]*stride+component])
		for i in loop.size():mesh.indices.append_array(PackedInt32Array([loop[(i+1)%loop.size()],loop[i],center_index]));added+=1
	return added

static func collapse_tiny_edges(mesh:Dictionary)->bool:
	var candidates:=PackedInt32Array()
	for i in range(0,mesh.indices.size(),3):
		var a:Vector3=mesh.vertices[mesh.indices[i]];var b:Vector3=mesh.vertices[mesh.indices[i+1]];var c:Vector3=mesh.vertices[mesh.indices[i+2]]
		var longest:float=maxf(a.distance_squared_to(b),maxf(b.distance_squared_to(c),c.distance_squared_to(a)))
		if (b-a).cross(c-a).length_squared()<=maxf(1e-14,longest*longest*4e-6):candidates.append(i)
	if candidates.is_empty():return false
	var changed:=false
	var parent:=PackedInt32Array();parent.resize(mesh.vertices.size())
	for i in parent.size():parent[i]=i
	var neighbors:Dictionary={};var edge_faces:Dictionary={}
	for i in range(0,mesh.indices.size(),3):
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			if not neighbors.has(edge.x):neighbors[edge.x]={}
			if not neighbors.has(edge.y):neighbors[edge.y]={}
			neighbors[edge.x][edge.y]=true;neighbors[edge.y][edge.x]=true
			var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			edge_faces[key]=int(edge_faces.get(key,0))+1
	var locked:Dictionary={}
	for i:int in candidates:
		var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
		var x:Vector3=mesh.vertices[a];var y:Vector3=mesh.vertices[b];var z:Vector3=mesh.vertices[c]
		var longest:float=maxf(x.distance_squared_to(y),maxf(y.distance_squared_to(z),z.distance_squared_to(x)))
		if (y-x).cross(z-x).length_squared()>maxf(1e-14,longest*longest*4e-6):continue
		var shortest:=INF;var selected:=Vector2i(a,b)
		for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var distance:float=mesh.vertices[edge.x].distance_squared_to(mesh.vertices[edge.y])
			if distance<shortest:shortest=distance;selected=edge
		if shortest>=maxf(1e-8,longest*.0025) or locked.has(selected.x) or locked.has(selected.y):continue
		var common:=0
		for id:int in neighbors[selected.x]:
			if neighbors[selected.y].has(id):common+=1
		var key:=Vector2i(mini(selected.x,selected.y),maxi(selected.x,selected.y))
		# The edge-collapse link condition preserves the manifold. Lock its
		# one-ring so simultaneous local repairs cannot invalidate that test.
		var incidence:int=edge_faces.get(key,0)
		if not ((incidence==2 and common==2) or (incidence==1 and common==1)):continue
		var adjacent_locked:=false
		for id:int in neighbors[selected.x]:
			if locked.has(id):adjacent_locked=true;break
		if adjacent_locked:continue
		changed=true
		parent[selected.y]=selected.x;locked[selected.x]=true;locked[selected.y]=true
		for id:int in neighbors[selected.x]:locked[id]=true
		for id:int in neighbors[selected.y]:locked[id]=true
	for i in mesh.indices.size():mesh.indices[i]=_root(parent,mesh.indices[i])
	return changed

static func repair_t_junctions(mesh:Dictionary)->int:
	var repaired:=0
	for pass_id in 4:
		var edges:Dictionary={}
		for i in range(0,mesh.indices.size(),3):
			var a:int=mesh.indices[i];var b:int=mesh.indices[i+1];var c:int=mesh.indices[i+2]
			for edge:Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
				var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
				if not edges.has(key):edges[key]=[]
				edges[key].append({"a":edge.x,"b":edge.y,"face":i/3})
		var boundary:Array[Dictionary]=[];var vertices:Dictionary={}
		for items:Array in edges.values():
			if items.size()!=1:continue
			boundary.append(items[0]);vertices[items[0].a]=true;vertices[items[0].b]=true
		var changes:Dictionary={}
		for edge:Dictionary in boundary:
			if changes.has(edge.face):continue
			var a:Vector3=mesh.vertices[edge.a];var b:Vector3=mesh.vertices[edge.b];var line:=b-a
			var third:int=mesh.indices[edge.face*3]
			for k in 3:
				var id:int=mesh.indices[edge.face*3+k]
				if id!=edge.a and id!=edge.b:third=id
			var best:=-1;var error:=1e-10
			for vertex:int in vertices:
				if vertex in [edge.a,edge.b,third]:continue
				var point:Vector3=mesh.vertices[vertex]
				var t:=clampf((point-a).dot(line)/maxf(line.length_squared(),1e-12),0,1)
				if t<.00001 or t>.99999:continue
				var distance:=point.distance_squared_to(a+line*t)
				if distance<error:best=vertex;error=distance
			if best>=0:changes[edge.face]=PackedInt32Array([edge.a,best,third,best,edge.b,third]);repaired+=1
		if changes.is_empty():break
		var indices:=PackedInt32Array()
		for face in mesh.indices.size()/3:
			if changes.has(face):indices.append_array(changes[face])
			else:indices.append_array(mesh.indices.slice(face*3,face*3+3))
		mesh.indices=indices
	return repaired
