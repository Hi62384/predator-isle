extends "res://scripts/caves/surface_context.gd"
## Exact render-only sharing. Native collision remains the original triangle soup.
func surfaces(arrays:Array,chunk_origin:Vector3)->Dictionary:
	if arrays.is_empty():return {"valid":true,"groups":{},"collision_faces":PackedVector3Array()}
	var groups:Dictionary={};var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,positions.size(),3):
		var center:Vector3=(positions[i]+positions[i+1]+positions[i+2])/3+chunk_origin;var ground:float=height_at(center.x,center.z);var id:String=owner_at(Vector2(center.x,center.z)) if ground-center.y<12 else "";var group_key:String=id if not id.is_empty() else "__interior__"
		if not groups.has(group_key):groups[group_key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"payload":PackedFloat32Array(),"indices":PackedInt32Array(),"lookup":{}}
		var group:Dictionary=groups[group_key]
		for j in range(3):
			var local:Vector3=positions[i+j];var n:Vector3=normals[i+j];var color:Color=arrays[Mesh.ARRAY_COLOR][i+j] if arrays[Mesh.ARRAY_COLOR]!=null else Color(.38,.35,.30,1)
			# Include all input bits,not an approximate positional weld. Distinct
			# sharp normals/colors and material owners never merge.
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
	return {"valid":true,"groups":groups,"collision_faces":positions}
