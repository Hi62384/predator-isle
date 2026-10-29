extends RefCounted
## Worker-owned canonical field. No resources, nodes, simulations or unbounded searches.
## State: physical height, retained freshwater elevation (0 = none), wetness,
## regional identity [0,1], semantic feature intensity [0,1].
const STEP:float=16
var settings:Resource
var seed_value:int
var family:int
var state:=PackedFloat64Array([0,0,0,0,0])
var _host:WeakRef
var _nodes:Dictionary={}
var _node_ring:Array[Vector2i]=[]
var _node_cursor:int=0
var _descriptors:Dictionary={}
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _regions:=FastNoiseLite.new()
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	settings=config;seed_value=seed_id;family=family_id;_host=weakref(host)
	for item in [[_macro,41011,1.0/2300,2],[_meso,41039,1.0/230,2],[_regions,41077,1.0/maxf(settings.region_metres,1000),1]]:
		var n:FastNoiseLite=item[0];n.seed=seed_id+item[1]+family*1009;n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.32
	_nodes.clear();_descriptors.clear();_node_ring.clear();_node_cursor=0
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+(salt+family*301)*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func descriptor(cell:Vector2i,span:float)->Dictionary:
	var key:=Vector3i(cell.x,cell.y,roundi(span))
	if _descriptors.has(key):return _descriptors[key]
	var p:Vector2=(Vector2(cell)+Vector2(.25+random(cell.x,cell.y,1)*.5,.25+random(cell.x,cell.y,2)*.5))*span
	var d:Dictionary={"id":str(family)+":"+str(cell.x)+":"+str(cell.y),"position":p,"radius":span*(.2+.18*random(cell.x,cell.y,3)),"age":random(cell.x,cell.y,4),"kind":mini(5,int(random(cell.x,cell.y,5)*6)),"angle":random(cell.x,cell.y,6)*TAU,"chance":random(cell.x,cell.y,7)}
	if _descriptors.size()>=512:_descriptors.clear()
	_descriptors[key]=d;return d
func nearby(p:Vector2,span:float)->Dictionary:
	var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var best:Dictionary={};var distance:float=INF
	for z in range(-1,2):
		for x in range(-1,2):
			var d:Dictionary=descriptor(cell+Vector2i(x,z),span);var score:float=p.distance_squared_to(d.position)
			if score<distance:distance=score;best=d
	return best
func local(p:Vector2,d:Dictionary)->Vector2:
	return (p-d.position).rotated(-d.angle)
func segment(p:Vector2,a:Vector2,b:Vector2)->Vector2:
	var ab:Vector2=b-a;var t:float=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.001),0,1)
	return Vector2(p.distance_to(a+ab*t),t)
func noise(p:Vector2)->float:return _meso.get_noise_2dv(p)
func macro(p:Vector2)->float:return _macro.get_noise_2dv(p)
func region(p:Vector2)->float:return clampf((_regions.get_noise_2dv(p)*.8+.5)*5,0,4.99999)
func sample(x:float,z:float,publish:bool=true)->float:
	var p:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(p.x),floori(p.y));var f:Vector2=p-Vector2(cell)
	if f==Vector2.ZERO:
		var value:PackedFloat64Array=_node(cell)
		if publish:state=value.duplicate()
		return value[0]
	f=Vector2(smoothstep(0,1,f.x),smoothstep(0,1,f.y))
	var a:PackedFloat64Array=_node(cell);var b:PackedFloat64Array=_node(cell+Vector2i.RIGHT);var c:PackedFloat64Array=_node(cell+Vector2i.DOWN);var d:PackedFloat64Array=_node(cell+Vector2i.ONE)
	var h:float=lerpf(lerpf(a[0],b[0],f.x),lerpf(c[0],d[0],f.x),f.y)
	if publish:
		state.resize(5);state[0]=h
		for i in range(1,5):state[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return h
func _node(cell:Vector2i)->PackedFloat64Array:
	if _nodes.has(cell):return _nodes[cell]
	var p:Vector2=Vector2(cell)*STEP;var r:float=region(p);var id:int=floori(r);var f:float=smoothstep(.25,.75,r-floorf(r))
	var a:PackedFloat64Array=evaluate(p,id);var b:PackedFloat64Array=evaluate(p,mini(id+1,5)) if f>0 else a
	var v:=PackedFloat64Array();v.resize(5)
	for i in range(5):v[i]=lerpf(a[i],b[i],f)
	v[0]*=settings.relief;v[1]*=settings.relief;v[3]=r/5
	# Fixed FIFO eviction retains the other three corners and recent normal
	# probes; clearing the entire cache caused avoidable cold rebuild spikes.
	if _node_ring.size()<8192:_node_ring.append(cell)
	else:
		_nodes.erase(_node_ring[_node_cursor]);_node_ring[_node_cursor]=cell;_node_cursor=(_node_cursor+1)%8192
	_nodes[cell]=v;return v
func evaluate(_p:Vector2,_region:int)->PackedFloat64Array:
	return PackedFloat64Array([0,0,0,0,0])
func describe(p:Vector2)->Dictionary:
	sample(p.x,p.y)
	return {"family":family,"height":state[0],"water_level":state[1],"wetness":state[2],"region":state[3]*5,"feature":state[4],"caves_supported":settings.caves_enabled and family in [1,2,6,7],"cave_placement":"Finite dry-site portals only, not arbitrary heightfield excavation"}
