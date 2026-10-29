extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Assimilation fringe","Nerve lowlands","Carapace highlands","Membrane sinklands","Hive rupture country","Ancient dormant tissue"]
var _network_cache:Dictionary={}
var _hive_nodes:Dictionary={}
var _network_edges:Dictionary={}
var _edge_bounds:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	super.configure(config,seed_id,host,family_id)
	_network_cache.clear();_hive_nodes.clear();_network_edges.clear();_edge_bounds.clear()
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
	var bounds:=PackedVector4Array()
	for edge in range(0,8,4):
		for pair:Vector2i in [Vector2i(edge,edge+1),Vector2i(edge+1,edge+2),Vector2i(edge+1,edge+3)]:
			var p:Vector2=edges[pair.x];var q:Vector2=edges[pair.y]
			# Outward padding covers float32 endpoint/projection rounding at
			# signed large world positions. Bounds may over-admit, never clip.
			var padding:float=maxf(maxf(absf(p.x),absf(p.y)),maxf(absf(q.x),absf(q.y)))*.0000005+.001
			bounds.append(Vector4(minf(p.x,q.x)-padding,minf(p.y,q.y)-padding,maxf(p.x,q.x)+padding,maxf(p.y,q.y)+padding))
	if _network_edges.size()>=512:_network_edges.clear();_edge_bounds.clear()
	_network_edges[cell]=edges;_edge_bounds[cell]=bounds;return edges
func network(p:Vector2)->Dictionary:
	if _network_cache.has(p):return _network_cache[p]
	var span:float=4096*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var trunk_squared:float=INF;var branch_squared:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String=""
	for z in range(-1,2):
		for x in range(-1,2):
			var c:=cell+Vector2i(x,z);var a:Vector2=hive_node(c)
			var candidate:float=p.distance_to(a)
			if candidate<center:center=candidate;nearest=a;identity=str(c)
			var edges:PackedVector2Array=network_edges(c)
			var bounds:PackedVector4Array=_edge_bounds[c]
			for edge in range(0,8,4):
				var b:Vector2=edges[edge+2];var mid:Vector2=edges[edge+1]
				var index:int=0 if edge==0 else 3
				trunk_squared=minf(trunk_squared,bounded_segment_squared(p,a,mid,bounds[index],trunk_squared))
				trunk_squared=minf(trunk_squared,bounded_segment_squared(p,mid,b,bounds[index+1],trunk_squared))
				var tip:Vector2=edges[edge+3]
				branch_squared=minf(branch_squared,bounded_segment_squared(p,mid,tip,bounds[index+2],branch_squared))
	# Distance ordering is monotone. Keep only two square roots, rounding
	# their outputs to the original Vector2 distance channel's float32 format.
	var trunk:float=Vector2(sqrt(trunk_squared),0).x;var branch:float=Vector2(sqrt(branch_squared),0).x
	# Compact supports leave genuinely unaffected ground between local fronts.
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result;return result
func segment_squared(p:Vector2,a:Vector2,b:Vector2)->float:
	var ab:Vector2=b-a;var t:float=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.001),0,1)
	return p.distance_squared_to(a+ab*t)
func bounded_segment_squared(p:Vector2,a:Vector2,b:Vector2,bounds:Vector4,limit:float)->float:
	var closest:=Vector2(clampf(p.x,bounds.x,bounds.z),clampf(p.y,bounds.y,bounds.w))
	if p.distance_squared_to(closest)>limit:return limit
	return segment_squared(p,a,b)
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
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
	return PackedFloat64Array([h,0,.25+influence*.5,0,influence])
func describe(p:Vector2)->Dictionary:
	var v:Dictionary=super.describe(p);v.merge(network(p));v["infection_age"]=v.age;v["infection_intensity"]=v.influence
	v["underground_center"]=Vector3(v.center.x,-900,v.center.y)
	v["organic_fluid"]={"eligible":v.region>2.6 and v.region<3.5 and v.center_distance<300,"renderer_supported":true,"rendered":"Only retained basins passing the feature mesher's bed/rim test"}
	v["breach_traversable"]=false;return v
