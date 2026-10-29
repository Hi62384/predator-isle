extends RefCounted
## Canonical material coordinates from actual finite hive paths.
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
static func atlas(field,origin:Vector2,span:float,resolution:int)->Dictionary:
	#8m near material samples,never denser than the terrain,maximum129².
	var cells:int=mini(resolution,maxi(1,ceili(span/8.0)))
	return rectangle(field,origin,Vector2.ONE*span,Vector2i(cells,cells))
static func rectangle(field,origin:Vector2,span:Vector2,cells:Vector2i)->Dictionary:
	var columns:int=cells.x+1;var rows:int=cells.y+1
	var pixels:=PackedFloat32Array();pixels.resize(columns*rows*4)
	var ids:Dictionary={};var nonzero:bool=false
	for z in range(rows):
		for x in range(columns):
			var p:Vector2=origin+Vector2(x,z)*(span/Vector2(cells));var value:Vector4=packed_sample(field,p,ids)
			if value.w<=0:continue
			var offset:int=(z*columns+x)*4
			pixels[offset]=value.x;pixels[offset+1]=value.y;pixels[offset+2]=value.z;pixels[offset+3]=value.w;nonzero=true
	return {"data":pixels.to_byte_array() if nonzero else PackedByteArray(),"columns":columns if nonzero else 0,"rows":rows if nonzero else 0}
static func packed_sample(field,p:Vector2,ids:Dictionary)->Vector4:
	# The atlas needs four floats,not a per-point diagnostic dictionary. Keep
	# the exact same projection/order/weight formula as sample(),but construct
	# the chosen frame only once and omit it entirely outside finite support.
	var scale:float=field.settings.feature_scale;var span:float=4096*scale
	var parent:=Vector2i(floori(p.x/span),floori(p.y/span));var data:Dictionary=field.query_tile(p,parent)
	var nearest:float=INF;var second:float=INF;var chosen:int=-1;var a:=Vector2.ZERO;var b:=Vector2.ZERO
	for index in range(data.trunks.size()):
		var path:PackedVector2Array=data.trunks[index];var first:Vector2=field.segment(p,path[0],path[1]);var last:Vector2=field.segment(p,path[1],path[2]);var distance:float=minf(first.x,last.x)
		if distance<nearest:second=minf(second,nearest);nearest=distance;chosen=index;a=first;b=last
		else:second=minf(second,distance)
	if nearest>=300*scale:return Vector4.ZERO
	var path:PackedVector2Array=data.trunks[chosen]
	var node_distance:float=minf(p.distance_to(path[0]),p.distance_to(path[2]));var bend_distance:float=p.distance_to(path[1])
	var weight:float=(1-smoothstep(120*scale,300*scale,nearest))*smoothstep(10*scale,80*scale,maxf(0,second-nearest))*smoothstep(12*scale,80*scale,node_distance)*smoothstep(12*scale,80*scale,bend_distance)
	if weight<=0:return Vector4.ZERO
	var first:bool=a.x<=b.x;var start:Vector2=path[0] if first else path[1];var end:Vector2=path[1] if first else path[2]
	var tangent:Vector2=(end-start).normalized();var foot:Vector2=start.lerp(end,a.y if first else b.y)
	var arc:float=(start.distance_to(foot) if first else path[0].distance_to(path[1])+start.distance_to(foot))
	var label:Vector3i=data.labels[chosen]
	if not ids.has(label):ids[label]=ids.size()+1
	return Vector4(arc,nearest*signf(tangent.cross(p-foot)),weight,ids[label])
static func structure_atlas(builder,arrays:Array,origin:Vector2)->Dictionary:
	if arrays.is_empty() or not builder.settings.alien_infected.nerve_flow_texturing:return {}
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():return {}
	var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
	for vertex:Vector3 in vertices:
		var p:=Vector2(vertex.x,vertex.z);minimum=minimum.min(p);maximum=maximum.max(p)
	# A root owns the WHOLE structure,not only the portion inside its tile.
	# Pad its actual bounds;never clamp out-of-tile shells to a tile-edge UV.
	var offset:Vector2=(minimum/8).floor()*8-Vector2(8,8)
	var span:Vector2=(maximum/8).ceil()*8+Vector2(8,8)-offset
	var cells:=Vector2i(clampi(ceili(span.x/8),1,128),clampi(ceili(span.y/8),1,128))
	var result:Dictionary=rectangle(builder._extras[7],origin+offset,span,cells)
	if result.data.is_empty():return {}
	result["offset"]=offset;result["span"]=span;return result

