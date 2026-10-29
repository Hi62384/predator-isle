extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Assimilation fringe","Nerve lowlands","Carapace highlands","Membrane sinklands","Hive rupture country","Ancient dormant tissue"]
var _network_cache:Dictionary={}
var _hive_nodes:Dictionary={}
func hive_node(cell:Vector2i)->Vector2:
	if _hive_nodes.has(cell):return _hive_nodes[cell]
	var p:Vector2=(Vector2(cell)+Vector2(.3+random(cell.x,cell.y,31)*.4,.3+random(cell.x,cell.y,32)*.4))*4096*settings.feature_scale
	if _hive_nodes.size()>=512:_hive_nodes.clear()
	_hive_nodes[cell]=p;return p
func network(p:Vector2)->Dictionary:
	if _network_cache.has(p):return _network_cache[p]
	var span:float=4096*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span));var trunk:float=INF;var branch:float=INF;var center:float=INF;var nearest:=Vector2.ZERO;var identity:String=""
	for z in range(-1,2):
		for x in range(-1,2):
			var c:=cell+Vector2i(x,z);var a:Vector2=hive_node(c)
			if p.distance_to(a)<center:center=p.distance_to(a);nearest=a;identity=str(c)
			for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
				var b:Vector2=hive_node(c+direction);var mid:Vector2=(a+b)*.5+Vector2(-(b-a).y,(b-a).x)*(.08*sin(float(c.x+c.y)*1.71))
				trunk=minf(trunk,minf(segment(p,a,mid).x,segment(p,mid,b).x))
				var tip:Vector2=mid+Vector2(-(b-a).y,(b-a).x)*.23
				branch=minf(branch,segment(p,mid,tip).x)
	# Compact supports leave genuinely unaffected ground between local fronts.
	var influence:float=maxf(exp(-trunk/340)*(1-smoothstep(900,1600,trunk)),exp(-branch/110)*.65*(1-smoothstep(400,700,branch)))
	var result:Dictionary={"id":identity,"center":nearest,"center_distance":center,"trunk_distance":trunk,"branch_distance":branch,"influence":influence,"age":.5+.5*macro(p*.25),"underground_geometry":false}
	if _network_cache.size()>=8192:_network_cache.clear()
	_network_cache[p]=result;return result
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
