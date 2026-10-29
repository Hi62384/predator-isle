extends "res://tools/biome_extensions/reference_pre_network_tiles_alien_sampler.gd"
## Private exact-query acceleration study. Bounds are paid once per small tile,
## not at every segment projection. Not registered in production workers.
var _query_tiles:Dictionary={}
var _tile_probes:Dictionary={}
var tile_hits:int=0
var tile_builds:int=0
var probe_resets:int=0
var uncached_queries:int=0
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	super.configure(config,seed_id,host,family_id);_query_tiles.clear();_tile_probes.clear();tile_hits=0;tile_builds=0;probe_resets=0;uncached_queries=0
func lower_bound(a:Vector2,b:Vector2,bounds:PackedFloat64Array)->float:
	# Distance between segment AABB and expanded query rectangle is a LOWER
	# bound on every point-to-segment distance inside that query rectangle.
	var x:float=maxf(0,maxf(minf(a.x,b.x)-bounds[2],bounds[0]-maxf(a.x,b.x)))
	var z:float=maxf(0,maxf(minf(a.y,b.y)-bounds[3],bounds[1]-maxf(a.y,b.y)))
	return sqrt(x*x+z*z)
func query_tile(p:Vector2,parent:Vector2i)->Dictionary:
	var step:float=256*settings.feature_scale;var key:=Vector2i(floori(p.x/step),floori(p.y/step))
	if _query_tiles.has(key) and _query_tiles[key].parent==parent:tile_hits+=1;return _query_tiles[key]
	tile_builds+=1
	var magnitude:float=maxf(maxf(absf(key.x*step),absf((key.x+1)*step)),maxf(absf(key.y*step),absf((key.y+1)*step)))
	var pad:float=.25+magnitude*.000004
	var bounds:=PackedFloat64Array([key.x*step-pad,key.y*step-pad,(key.x+1)*step+pad,(key.y+1)*step+pad])
	var center:=Vector2((key.x+.5)*step,(key.y+.5)*step);var radius:float=step*sqrt(.5)+pad*2
	var nodes:=PackedVector2Array();var names:Array[String]=[];var paths:Array[PackedVector2Array]=[];var labels:Array[Vector3i]=[];var branch_paths:Array[PackedVector2Array]=[]
	var trunk_upper:float=INF;var branch_upper:float=INF
	for z in range(-1,2):
		for x in range(-1,2):
			var cell:Vector2i=parent+Vector2i(x,z);var a:Vector2=hive_node(cell);nodes.append(a);names.append(str(cell));var edges:PackedVector2Array=network_edges(cell)
			for edge in range(0,8,4):
				var mid:Vector2=edges[edge+1];var b:Vector2=edges[edge+2];var tip:Vector2=edges[edge+3]
				paths.append(PackedVector2Array([a,mid,b]));labels.append(Vector3i(cell.x,cell.y,edge/4));branch_paths.append(PackedVector2Array([mid,tip]))
				trunk_upper=minf(trunk_upper,minf(segment(center,a,mid).x,segment(center,mid,b).x)+radius)
				branch_upper=minf(branch_upper,segment(center,mid,tip).x+radius)
	var trunks:Array[PackedVector2Array]=[];var trunk_labels:Array[Vector3i]=[];var branches:Array[PackedVector2Array]=[]
	for i in range(paths.size()):
		var path:PackedVector2Array=paths[i]
		# Keep every possible nearest path AND every path that can influence
		# the fibre's nearest/second-nearest isolation interval. Farther second
		# paths all produce the same exactly saturated isolation value of one.
		if minf(lower_bound(path[0],path[1],bounds),lower_bound(path[1],path[2],bounds))<=trunk_upper+100*settings.feature_scale:
			trunks.append(path);trunk_labels.append(labels[i])
		var branch:PackedVector2Array=branch_paths[i]
		if lower_bound(branch[0],branch[1],bounds)<=branch_upper:branches.append(branch)
	assert(not trunks.is_empty() and not branches.is_empty())
	var value:Dictionary={"parent":parent,"nodes":nodes,"names":names,"trunks":trunks,"labels":trunk_labels,"branches":branches}
	if _query_tiles.size()>=512:_query_tiles.clear()
	_query_tiles[key]=value;return value
func network(p:Vector2)->Dictionary:
	var frame_needed:bool=_want_frame and settings.nerve_fibre_height>0
	if _network_cache.has(p) and (not frame_needed or _last_frame_point==p):return _network_cache[p]
	# Sparse far meshes and isolated random probes do not amortize tile bounds.
	# Observe four distinct uncached queries before paying that construction cost.
	var step:float=256*settings.feature_scale;var key:=Vector2i(floori(p.x/step),floori(p.y/step))
	if not _query_tiles.has(key):
		if _tile_probes.size()>=512 and not _tile_probes.has(key):_tile_probes.clear();probe_resets+=1
		var count:int=int(_tile_probes.get(key,0))+1;_tile_probes[key]=count
		if count<4:uncached_queries+=1;return super.network(p)
	var span:float=4096*settings.feature_scale;var parent:=Vector2i(floori(p.x/span),floori(p.y/span));var data:Dictionary=query_tile(p,parent)
	var trunk:float=INF;var second:float=INF;var branch:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String="";var frame:Dictionary={}
	for i in range(data.nodes.size()):
		var node:Vector2=data.nodes[i];var distance:float=p.distance_to(node)
		if distance<center:center=distance;nearest=node;identity=data.names[i]
	for i in range(data.trunks.size()):
		var path:PackedVector2Array=data.trunks[i];var first:Vector2=segment(p,path[0],path[1]);var last:Vector2=segment(p,path[1],path[2]);var distance:float=minf(first.x,last.x)
		if frame_needed:
			if distance<trunk:
				second=minf(second,trunk);var label:Vector3i=data.labels[i]
				frame={"start":path[0] if first.x<=last.x else path[1],"end":path[1] if first.x<=last.x else path[2],"t":first.y*.5 if first.x<=last.x else .5+last.y*.5,"cell":Vector2i(label.x,label.y),"edge":label.z}
			else:second=minf(second,distance)
		trunk=minf(trunk,distance)
	for path:PackedVector2Array in data.branches:branch=minf(branch,segment(p,path[0],path[1]).x)
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if not _network_cache.has(p) and _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result
	if frame_needed:frame["gap"]=maxf(0,second-trunk);_last_frame=frame;_last_frame_point=p
	return result
