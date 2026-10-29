extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Assimilation fringe","Nerve lowlands","Carapace highlands","Membrane sinklands","Hive rupture country","Ancient dormant tissue"]
var _network_cache:Dictionary={}
var _hive_nodes:Dictionary={}
var _network_edges:Dictionary={}
var _query_tiles:Dictionary={}
var _tile_probes:Dictionary={}
var tile_hits:int=0
var tile_builds:int=0
var probe_resets:int=0
var uncached_queries:int=0
# Private one-point projection frame; never changes the public network payload.
var _want_frame:bool=false
var _last_frame_point:=Vector2.INF
var _last_frame:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	super.configure(config,seed_id,host,family_id)
	_network_cache.clear();_hive_nodes.clear();_network_edges.clear()
	_want_frame=false;_last_frame_point=Vector2.INF;_last_frame={}
	_query_tiles.clear();_tile_probes.clear();tile_hits=0;tile_builds=0;probe_resets=0;uncached_queries=0
func hive_node(cell:Vector2i)->Vector2:
	if _hive_nodes.has(cell):return _hive_nodes[cell]
	var p:Vector2=(Vector2(cell)+Vector2(.3+random(cell.x,cell.y,31)*.4,.3+random(cell.x,cell.y,32)*.4))*4096*settings.feature_scale
	if _hive_nodes.size()>=512:_hive_nodes.clear()
	_hive_nodes[cell]=p;return p
func network_edges(cell:Vector2i)->PackedVector2Array:
	if _network_edges.has(cell):return _network_edges[cell]
	# Immutable path geometry is shared by all queries in this cell. The
	# arithmetic/order is identical to the original per-query construction.
	var a:Vector2=hive_node(cell);var edges:=PackedVector2Array()
	for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
		var b:Vector2=hive_node(cell+direction);var mid:Vector2=(a+b)*.5+Vector2(-(b-a).y,(b-a).x)*(.08*sin(float(cell.x+cell.y)*1.71))
		var tip:Vector2=mid+Vector2(-(b-a).y,(b-a).x)*.23
		edges.append_array(PackedVector2Array([a,mid,b,tip]))
	if _network_edges.size()>=512:_network_edges.clear()
	_network_edges[cell]=edges;return edges
func _network_without_fibres(p:Vector2)->Dictionary:
	if _network_cache.has(p):return _network_cache[p]
	var span:float=4096*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var trunk:float=INF;var branch:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String=""
	for z in range(-1,2):
		for x in range(-1,2):
			var c:=cell+Vector2i(x,z);var a:Vector2=hive_node(c)
			if p.distance_to(a)<center:center=p.distance_to(a);nearest=a;identity=str(c)
			var edges:PackedVector2Array=network_edges(c)
			for edge in range(0,8,4):
				var b:Vector2=edges[edge+2];var mid:Vector2=edges[edge+1]
				trunk=minf(trunk,minf(segment(p,a,mid).x,segment(p,mid,b).x))
				var tip:Vector2=edges[edge+3]
				branch=minf(branch,segment(p,mid,tip).x)
	# Compact supports leave genuinely unaffected ground between local fronts.
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result;return result
func _node(cell:Vector2i)->PackedFloat64Array:
	if settings.nerve_fibre_height<=0 or _nodes.has(cell):return super._node(cell)
	# Prepare the frame on the first regional evaluation at this lattice point,
	# including a fringe/nerve blend. Do not project all segments a second time.
	var r:float=region(Vector2(cell)*STEP);var id:int=floori(r);var previous:bool=_want_frame
	_want_frame=id==1 or (id==0 and smoothstep(.25,.75,r-floorf(r))>0)
	var value:PackedFloat64Array=super._node(cell);_want_frame=previous;return value
func network(p:Vector2)->Dictionary:
	if not settings.network_query_cache_enabled:
		if not _query_tiles.is_empty():_query_tiles.clear()
		if not _tile_probes.is_empty():_tile_probes.clear()
		return _network_unpruned(p)
	return _network_tiled(p)
func _network_unpruned(p:Vector2)->Dictionary:
	if not _want_frame or settings.nerve_fibre_height<=0:return _network_without_fibres(p)
	if _network_cache.has(p) and _last_frame_point==p:return _network_cache[p]
	var span:float=4096*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var trunk:float=INF;var second:float=INF;var branch:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String="";var frame:Dictionary={}
	for z in range(-1,2):
		for x in range(-1,2):
			var c:=cell+Vector2i(x,z);var a:Vector2=hive_node(c)
			if p.distance_to(a)<center:center=p.distance_to(a);nearest=a;identity=str(c)
			var edges:PackedVector2Array=network_edges(c)
			for edge in range(0,8,4):
				var b:Vector2=edges[edge+2];var mid:Vector2=edges[edge+1]
				var first:Vector2=segment(p,a,mid);var last:Vector2=segment(p,mid,b);var distance:float=minf(first.x,last.x)
				if distance<trunk:
					second=minf(second,trunk)
					frame={"start":a if first.x<=last.x else mid,"end":mid if first.x<=last.x else b,"t":first.y*.5 if first.x<=last.x else .5+last.y*.5,"cell":c,"edge":edge/4}
				else:second=minf(second,distance)
				trunk=minf(trunk,distance)
				branch=minf(branch,segment(p,mid,edges[edge+3]).x)
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if not _network_cache.has(p) and _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result;frame["gap"]=maxf(0,second-trunk);_last_frame=frame;_last_frame_point=p;return result
func _fibre_relief(p:Vector2,net:Dictionary)->float:
	var frame:Dictionary=_last_frame;var t:float=frame.t;var scale:float=settings.feature_scale
	var arc:float=sin(t*PI);var taper:float=smoothstep(0,.15,t)*smoothstep(0,.15,1-t)
	var isolation:float=smoothstep(0,100*scale,frame.gap)
	# Use signed distance to the finite polyline, not distance to an infinite
	# segment line: closest-point changes around a bend must not step the field.
	var signed:float=net.trunk_distance*signf((frame.end-frame.start).cross(p-frame.start));var relief:float=0
	for i in range(3):
		var seed_offset:int=380+int(frame.edge)*19+i*3
		var maturity:float=.75+.5*random(frame.cell.x,frame.cell.y,seed_offset)
		var offset:float=[-140.0,90.0,260.0][i]*scale*arc*maturity
		offset+=macro(p*.6)*(30+i*20)*scale*arc*arc
		var width:float=[70.0,90.0,55.0][i]*scale*(.4+.6*arc)*(.8+.4*random(frame.cell.x,frame.cell.y,seed_offset+1))
		var q:float=absf(signed-offset)/maxf(width,.1);var crest:float=pow(maxf(0,1-q*q),3)
		relief=maxf(relief,crest*[1.0,.7,.4][i])
	return settings.nerve_fibre_height*minf(scale,1)*relief*taper*isolation*(.6+net.age*.4)
func nerve_fibre_relief(p:Vector2)->float:
	if settings.nerve_fibre_height<=0:return 0
	var previous:bool=_want_frame;_want_frame=true
	var value:float=_fibre_relief(p,network(p));_want_frame=previous;return value
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var previous:bool=_want_frame;_want_frame=_want_frame or (id==1 and settings.nerve_fibre_height>0)
	var net:Dictionary=network(p);var influence:float=net.influence
	var ridge:float=exp(-pow(net.trunk_distance/100,2))+exp(-pow(net.branch_distance/42,2))*.35
	var core:float=1-smoothstep(160,650,net.center_distance)
	var h:float=60+macro(p)*[45,20,280,35,100,170][id]+noise(p)*[2,2,5,1,4,4][id]
	h+=ridge*settings.nerve_height*(.7+net.age*.6)
	if id==2:h+=pow(1-absf(macro(p*.6)),4)*160
	if id==3:
		# An actual retained basin above ocean level, with incoming nerves fading
		# at its rim instead of making a raised ridge through the liquid centre.
		h+=50-core*75-ridge*settings.nerve_height*(.7+net.age*.6)*core
	if id==4:h+=core*45-core*core*settings.breach_depth
	if id==1 and settings.nerve_fibre_height>0:h+=_fibre_relief(p,net)
	_want_frame=previous
	return PackedFloat64Array([h,0,.25+influence*.5,0,influence])
func describe(p:Vector2)->Dictionary:
	var v:Dictionary=super.describe(p);v.merge(network(p));v["infection_age"]=v.age;v["infection_intensity"]=v.influence
	# Surface-only sampling must not invent an underground world-Y or claim
	# loaded traversable geometry. The shared cave region supplies its real
	# solved underground_hive_center independently of surface chunk loading.
	v["underground_center"]=null;v["underground_source"]="Shared cave region underground_hive_center;surface descriptors alone do not assert a traversable core"
	v["organic_fluid"]={"eligible":v.region>2.6 and v.region<3.5 and v.center_distance<300,"renderer_supported":true,"rendered":"Only retained basins passing the feature mesher's bed/rim test"}
	v["breach_traversable"]=false;return v
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
func _network_tiled(p:Vector2)->Dictionary:
	var frame_needed:bool=_want_frame and settings.nerve_fibre_height>0
	if _network_cache.has(p) and (not frame_needed or _last_frame_point==p):return _network_cache[p]
	# Sparse far meshes and isolated random probes do not amortize tile bounds.
	# Observe four distinct uncached queries before paying that construction cost.
	var step:float=256*settings.feature_scale;var key:=Vector2i(floori(p.x/step),floori(p.y/step))
	if not _query_tiles.has(key):
		if _tile_probes.size()>=512 and not _tile_probes.has(key):_tile_probes.clear();probe_resets+=1
		var count:int=int(_tile_probes.get(key,0))+1;_tile_probes[key]=count
		if count<4:uncached_queries+=1;return _network_unpruned(p)
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
