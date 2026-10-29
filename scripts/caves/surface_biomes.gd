extends RefCounted
## Four local blend channels,not four global biome types. IDs are attached to
## each cell and sorted;the registry can contain16different definitions.
static func bind(arrays:Array,field,key:Vector3i,chosen_ids:Array=[])->Dictionary:
	var ids:Array=chosen_ids if not chosen_ids.is_empty() else field.biome_ids_for_cell(key)
	if ids.size()>4:return {"valid":false,"reason":"More than four surface-biome overlaps in one cave cell","arrays":[],"ids":ids}
	if ids.is_empty() or arrays.is_empty():return {"valid":true,"arrays":arrays,"ids":ids}
	var output:Array=arrays.duplicate();var first:=PackedVector2Array();var second:=PackedVector2Array();var cache:Dictionary={};var origin:=Vector3(key)*64
	for vertex:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var point:Vector3=vertex+origin;var weights:Vector4
		if cache.has(point):weights=cache[point]
		else:weights=field.biome_weights_at(point,ids);cache[point]=weights
		first.append(Vector2(weights.x,weights.y));second.append(Vector2(weights.z,weights.w))
	output[Mesh.ARRAY_TEX_UV]=first;output[Mesh.ARRAY_TEX_UV2]=second;return {"valid":true,"arrays":output,"ids":ids}
