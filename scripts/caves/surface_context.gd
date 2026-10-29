extends RefCounted
## Worker-local snapshot of original parent terrain triangles and decoded
## material controls. Records contain numeric arrays,never Nodes/materials.
const Payload=preload("res://scripts/caves/surface_payload.gd")
var parents:Dictionary={}
var canonical:Callable
var _heights:Dictionary={}
var _height_ring:Array[Vector2]=[]
var _height_cursor:int=0
func configure(records:Array,original_height:Callable)->bool:
	parents.clear();canonical=original_height;_heights.clear();_height_ring.clear();_height_cursor=0
	if not original_height.is_valid():return false
	for record:Dictionary in records:
		if not record.has("id") or not record.has("origin") or not record.has("span") or not record.has("resolution") or not record.has("arrays"):parents.clear();return false
		if not record.origin.is_finite() or not is_finite(record.span) or record.span<=0 or record.resolution<1 or record.arrays.size()!=Mesh.ARRAY_MAX or record.arrays[Mesh.ARRAY_VERTEX]==null or record.arrays[Mesh.ARRAY_VERTEX].size()<(record.resolution+1)*(record.resolution+1):parents.clear();return false
		var data:Dictionary=record.duplicate();data["decoded"]={};parents[record.id]=data
	return not parents.is_empty()
func owner_at(point:Vector2)->String:
	var selected:String="";var smallest:float=INF
	for id:String in parents:
		var parent:Dictionary=parents[id];var origin:=Vector2(parent.origin.x,parent.origin.z);var local:Vector2=point-origin
		if local.x<0 or local.y<0 or local.x>parent.span or local.y>parent.span:continue
		if parent.span<smallest:smallest=parent.span;selected=id
	return selected
func selection(id:String,point:Vector2)->Dictionary:
	if not parents.has(id):return {}
	var parent:Dictionary=parents[id];return Payload.triangle(point-Vector2(parent.origin.x,parent.origin.z),parent.span,parent.resolution)
func contains_triangle(id:String,points:PackedVector3Array,first:int,origin:Vector3)->bool:
	for corner in range(3):
		var point:Vector3=points[first+corner]+origin
		if selection(id,Vector2(point.x,point.z)).is_empty():return false
	return true
func triangle_owner(points:PackedVector3Array,first:int,origin:Vector3,preferred:String)->String:
	# Preserve every already-valid payload bit. Far from origin,a centroid
	# within one float ULP of a shared boundary can round into the neighbour
	# although the whole triangle belongs to the original fine parent.
	if preferred.is_empty() or contains_triangle(preferred,points,first,origin):return preferred
	var ids:Array=parents.keys();ids.sort()
	for id:String in ids:
		if contains_triangle(id,points,first,origin):return id
	# Genuine cross-parent/out-of-coverage triangles remain rejected. Never
	# clamp a vertex,extrapolate payloads,drop geometry or alter collision.
	return preferred
func height_at(x:float,z:float)->float:
	var point:=Vector2(x,z);var cacheable:bool=point.x==x and point.y==z
	if not point.is_finite():return NAN
	if cacheable and _heights.has(point):return _heights[point]
	var value:float=uncached_height(point)
	if cacheable and is_finite(value):
		if _height_ring.size()<8192:_height_ring.append(point)
		else:_heights.erase(_height_ring[_height_cursor]);_height_ring[_height_cursor]=point;_height_cursor=(_height_cursor+1)%8192
		_heights[point]=value
	return value
func uncached_height(point:Vector2)->float:
	var id:String=owner_at(point)
	if id.is_empty():return canonical.call(point.x,point.y)
	var parent:Dictionary=parents[id];var chosen:Dictionary=selection(id,point)
	if chosen.is_empty():return NAN
	var positions:PackedVector3Array=parent.arrays[Mesh.ARRAY_VERTEX];var y:float=0
	for corner in range(3):y+=positions[chosen.indices[corner]].y*chosen.weights[corner]
	return y+parent.origin.y
func controls(id:String,point:Vector2)->PackedFloat32Array:
	var chosen:Dictionary=selection(id,point)
	if chosen.is_empty():return PackedFloat32Array()
	var parent:Dictionary=parents[id];var result:=PackedFloat32Array();result.resize(Payload.STRIDE)
	for corner in range(3):
		var index:int=chosen.indices[corner]
		if not parent.decoded.has(index):parent.decoded[index]=Payload.decode(parent.arrays,index,parent.get("extension_normalization",false))
		var values:PackedFloat32Array=parent.decoded[index]
		if values.size()!=Payload.STRIDE:return PackedFloat32Array()
		for component in range(Payload.STRIDE):result[component]+=float(values[component])*chosen.weights[corner]
	return result
func normal_at(id:String,point:Vector2)->Vector3:
	var chosen:Dictionary=selection(id,point)
	if chosen.is_empty() or parents[id].arrays[Mesh.ARRAY_NORMAL]==null:return Vector3.UP
	var normals:PackedVector3Array=parents[id].arrays[Mesh.ARRAY_NORMAL];var value:=Vector3.ZERO
	for corner in range(3):value+=normals[chosen.indices[corner]]*chosen.weights[corner]
	return value.normalized()
func surfaces(arrays:Array,chunk_origin:Vector3)->Dictionary:
	if arrays.is_empty():return {"valid":true,"groups":{},"collision_faces":PackedVector3Array()}
	var groups:Dictionary={};var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,positions.size(),3):
		var center:Vector3=(positions[i]+positions[i+1]+positions[i+2])/3+chunk_origin;var ground:float=height_at(center.x,center.z);var id:String=triangle_owner(positions,i,chunk_origin,owner_at(Vector2(center.x,center.z))) if ground-center.y<12 else "";var group_key:String=id if not id.is_empty() else "__interior__"
		if not groups.has(group_key):groups[group_key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"payload":PackedFloat32Array()}
		var group:Dictionary=groups[group_key]
		for j in range(3):
			var world:Vector3=positions[i+j]+chunk_origin;var n:Vector3=normals[i+j]
			if not id.is_empty():
				var payload:PackedFloat32Array=controls(id,Vector2(world.x,world.z))
				if payload.is_empty():return {"valid":false,"reason":"Surface replacement triangle crosses unsupported parent boundary"}
				# The previously padded component transports physical entry depth.
				# No packed terrain field is overwritten to carry this new value.
				var depth:float=height_at(world.x,world.z)-world.y;payload[67]=maxf(0,depth);group.payload.append_array(payload);n=n.lerp(normal_at(id,Vector2(world.x,world.z)),1-smoothstep(0,2,depth)).normalized()
			group.vertices.append(positions[i+j]);group.normals.append(n);group.colors.append(arrays[Mesh.ARRAY_COLOR][i+j] if arrays[Mesh.ARRAY_COLOR]!=null else Color(.38,.35,.30,1))
	for id:String in groups:
		var group:Dictionary=groups[id];var built:Array=[];built.resize(Mesh.ARRAY_MAX);built[Mesh.ARRAY_VERTEX]=group.vertices;built[Mesh.ARRAY_NORMAL]=group.normals;built[Mesh.ARRAY_COLOR]=group.colors;group["arrays"]=built
		if id!="__interior__":
			group["atlas"]=Payload.atlas(group.payload)
			if group.atlas.is_empty():return {"valid":false,"reason":"Surface material atlas exceeds declared per-group budget"}
	return {"valid":true,"groups":groups,"collision_faces":positions}
func surfaces_indexed(arrays:Array,chunk_origin:Vector3,retain_source:bool=false)->Dictionary:
	if arrays.is_empty():return {"valid":true,"groups":{},"collision_faces":PackedVector3Array()}
	var groups:Dictionary={};var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,positions.size(),3):
		var center:Vector3=(positions[i]+positions[i+1]+positions[i+2])/3+chunk_origin;var ground:float=height_at(center.x,center.z);var id:String=triangle_owner(positions,i,chunk_origin,owner_at(Vector2(center.x,center.z))) if ground-center.y<12 else "";var group_key:String=id if not id.is_empty() else "__interior__"
		if not groups.has(group_key):groups[group_key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"payload":PackedFloat32Array(),"indices":PackedInt32Array(),"lookup":{}}
		var group:Dictionary=groups[group_key]
		for j in range(3):
			var local:Vector3=positions[i+j];var n:Vector3=normals[i+j];var color:Color=arrays[Mesh.ARRAY_COLOR][i+j] if arrays[Mesh.ARRAY_COLOR]!=null else Color(.38,.35,.30,1)
			# Exact bits include sharp normals/colors. Parent material groups
			# own independent indices;this is not a spatial weld/mesh decimation.
			var key:PackedByteArray=PackedFloat32Array([local.x,local.y,local.z,n.x,n.y,n.z,color.r,color.g,color.b,color.a]).to_byte_array()
			if group.lookup.has(key):group.indices.append(group.lookup[key]);continue
			var index:int=group.vertices.size();group.lookup[key]=index;group.indices.append(index);var world:Vector3=local+chunk_origin
			if not id.is_empty():
				var payload:PackedFloat32Array=controls(id,Vector2(world.x,world.z))
				if payload.is_empty():return {"valid":false,"reason":"Surface replacement triangle crosses unsupported parent boundary"}
				var depth:float=height_at(world.x,world.z)-world.y;payload[67]=maxf(0,depth);group.payload.append_array(payload);n=n.lerp(normal_at(id,Vector2(world.x,world.z)),1-smoothstep(0,2,depth)).normalized()
			group.vertices.append(local);group.normals.append(n);group.colors.append(color)
	for id:String in groups:
		var group:Dictionary=groups[id];var built:Array=[];built.resize(Mesh.ARRAY_MAX);built[Mesh.ARRAY_VERTEX]=group.vertices;built[Mesh.ARRAY_NORMAL]=group.normals;built[Mesh.ARRAY_COLOR]=group.colors;built[Mesh.ARRAY_INDEX]=group.indices;group["arrays"]=built;group.erase("lookup")
		if id!="__interior__":
			group["atlas"]=Payload.atlas(group.payload)
			if group.atlas.is_empty():return {"valid":false,"reason":"Surface material atlas exceeds declared per-group budget"}
		# Only the uploaded arrays/atlas cross the worker boundary. Retaining
		# decoded floats as well doubles the dominant immutable payload.
		if not retain_source:
			for field:String in ["vertices","normals","colors","indices","payload"]:group.erase(field)
	return {"valid":true,"groups":groups,"collision_faces":positions}
