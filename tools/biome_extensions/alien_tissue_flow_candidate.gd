extends RefCounted
## Private canonical material coordinates from actual finite hive paths.
## Independent of albedo,terrain height,camera,chunk and query order. Alignment
## fades out at competing paths,sharp polyline bends and shared hive nodes;
## these are real parameterization singularities,not places to stretch UVs.
static func sample(field,p:Vector2,tiled:bool=true)->Dictionary:
	var scale:float=field.settings.feature_scale;var span:float=4096*scale
	var parent:=Vector2i(floori(p.x/span),floori(p.y/span));var paths:Array=[];var labels:Array=[]
	if tiled:
		var tile:Dictionary=field.query_tile(p,parent);paths=tile.trunks;labels=tile.labels
	else:
		for z in range(-1,2):
			for x in range(-1,2):
				var cell:Vector2i=parent+Vector2i(x,z);var edges:PackedVector2Array=field.network_edges(cell)
				for edge in range(2):paths.append(PackedVector2Array([edges[edge*4],edges[edge*4+1],edges[edge*4+2]]));labels.append(Vector3i(cell.x,cell.y,edge))
	var nearest:float=INF;var second:float=INF;var result:Dictionary={}
	for index in range(paths.size()):
		var path:PackedVector2Array=paths[index];var a:Vector2=field.segment(p,path[0],path[1]);var b:Vector2=field.segment(p,path[1],path[2]);var distance:float=minf(a.x,b.x)
		if distance<nearest:
			second=minf(second,nearest);nearest=distance
			var first:bool=a.x<=b.x;var start:Vector2=path[0] if first else path[1];var end:Vector2=path[1] if first else path[2]
			var tangent:Vector2=(end-start).normalized();var foot:Vector2=start.lerp(end,a.y if first else b.y)
			var arc:float=(start.distance_to(foot) if first else path[0].distance_to(path[1])+start.distance_to(foot))
			result={"path":labels[index],"arc_metres":arc,"across_metres":distance*signf(tangent.cross(p-foot)),"tangent":tangent,"node_distance":minf(p.distance_to(path[0]),p.distance_to(path[2])),"bend_distance":p.distance_to(path[1])}
		else:second=minf(second,distance)
	assert(not result.is_empty())
	# The conservative existing query index retains every competitor within
	#100*scale,so its bounded isolation result equals a full graph scan.
	result["weight"]=(1-smoothstep(120*scale,300*scale,nearest))*smoothstep(10*scale,80*scale,maxf(0,second-nearest))*smoothstep(12*scale,80*scale,result.node_distance)*smoothstep(12*scale,80*scale,result.bend_distance)
	result["distance"]=nearest
	return result
