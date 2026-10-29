extends RefCounted
## Worker-owned, bounded, canonical terrain AND water-state sampler.
const NAMES=["Flooded lowland","Shallow water","Mudflat","River floodplain","Blackwater","Peatland","Muddy islands","Bayou","Seasonal basin","Hummock hollow","Deep backwater","Swamp lake","Rocky wetland","Coastal wetland","Drained upland"]
const STEP:float=16
var settings:Resource
var seed_value:int
var _host:WeakRef
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var _pools:Dictionary={}
var weights:=PackedFloat32Array()
## Height, local water, saturation, peat, sediment, channel, basin, levee,
## raised ground, rock, regional identity, organic-water character.
var state:=PackedFloat64Array()
func configure(config:Resource,world_seed:int,host:RefCounted)->void:
	settings=config;seed_value=world_seed;_host=weakref(host)
	for item in [[_macro,19701,1.0/7000,2],[_meso,19717,1.0/460,2],[_detail,19739,1.0/95,1]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.32
	_nodes.clear();_regions.clear();_pools.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	var occurrence:Array=[.25,.2,.16,settings.floodplain_frequency,.15,.2,settings.island_density*.3,.2,settings.basin_frequency,settings.raised_frequency*.4,.1,settings.basin_frequency*.6,.08,.08,settings.raised_frequency*.3]
	var mass:float=0
	for value:float in occurrence:mass+=maxf(value,0)
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var roll:float=random(q.x,q.y,7)*mass;var id:int=14
			for i in range(15):
				roll-=occurrence[i]
				if roll<=0:id=i;break
			var d:float=p.distance_to(site);closest=minf(closest,d);sites.append([d,id])
	var result:=PackedFloat32Array();result.resize(15);var total:float=0
	for site:Array in sites:
		var amount:float=1-smoothstep(0,span*.17,float(site[0])-closest);result[site[1]]+=amount;total+=amount
	for i in range(15):result[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:PackedFloat32Array=_region_node(cell)
	if f==Vector2.ZERO:return a
	var b:PackedFloat32Array=_region_node(cell+Vector2i.RIGHT);var c:PackedFloat32Array=_region_node(cell+Vector2i.DOWN);var d:PackedFloat32Array=_region_node(cell+Vector2i.ONE)
	if a==b and a==c and a==d:return a
	var result:=PackedFloat32Array();result.resize(15)
	for i in range(15):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return result

func water_table(p:Vector2)->float:
	# Connected channels share one continuous, gently graded potential.
	return 7+_macro.get_noise_2d(p.x,p.y)*4+sin(p.x/18000+float(seed_value%31))*.8
func _pool_sites(cell:Vector2i)->Array:
	if _pools.has(cell):return _pools[cell]
	var sites:Array=[]
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=cell+Vector2i(x,z);var r:float=random(q.x,q.y,211)
			if r>settings.pool_frequency:continue
			var center:Vector2=(Vector2(q)+Vector2(.25+random(q.x,q.y,213)*.5,.25+random(q.x,q.y,217)*.5))*1800
			sites.append([center,170+r*420,.5+random(q.x,q.y,219)*.55,random(q.x,q.y,223)*TAU,water_table(center)+.7+r*2.5,r])
	if _pools.size()>=512:_pools.clear()
	_pools[cell]=sites;return sites
func _raw(p:Vector2)->PackedFloat64Array:
	var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var table:float=water_table(p)
	var raised:float=smoothstep(-.18,.22,b+a*.2)
	var ridge:float=1-smoothstep(.03,.18,absf(b+c*.15))
	var offset:float=w[0]*(-.5)+w[1]*(-.9)+w[2]*.65+w[3]*.3+w[4]*(-.3)+w[5]*.7+w[6]*(-.6)+w[7]*.25+w[8]*.15+w[9]*.6-w[10]*1.7-w[11]*1.2+w[12]*2.5+w[13]*(-.2)+w[14]*5
	offset+=(.55-settings.water_coverage)*4
	var land:float=offset+(b*2.2+a*.6)*settings.terrain_relief
	land+=raised*settings.island_height*settings.island_density*(w[0]*.8+w[1]*.6+w[6]*1.8+w[10]*.7+w[11]*.5+w[13])
	land+=ridge*settings.island_height*settings.raised_frequency*(w[3]+w[6]+w[7]+w[9])
	land+=c*settings.hummock_amplitude*(w[5]+w[9]*1.7+w[14]*.4)
	var hollow:float=1-smoothstep(.025,.15,absf(c+b*.2))
	land-=hollow*settings.hollow_frequency*(w[5]*.7+w[9]+w[8]*.4)
	var channel:float=0;var flood:float=0;var levee:float=0;var basin:float=0;var deposition:float=0;var abandoned:float=0
	var host:RefCounted=_host.get_ref()
	var spacing:float=4000/maxf(host.settings.grass_river_frequency,.01)
	if settings.channel_frequency>0:
		var lane:int=roundi(p.y/spacing)
		for j in range(-1,2):
			var carrier:Vector3=host._river_column(p.x,lane+j,spacing)
			var d:float=absf(p.y-carrier.x)/sqrt(1+carrier.y*carrier.y)
			var width:float=settings.channel_width*(.8+.25*sin(p.x/700+float(lane+j)*1.7))*(.65+w[3]+w[7]*.8+w[4]*.3)
			if d>width+1100:continue
			var country:float=settings.channel_frequency*(.4+w[3]*.6+w[7]*.6+w[4]*.4)
			# A continuous core, not a weak regional carve that breaks into pools.
			var bed:float=(1-smoothstep(width*.35,width,d))*smoothstep(0,.25,settings.channel_frequency)
			var fp:float=(1-smoothstep(width, width+650,d))*settings.floodplain_connectivity
			var bank:float=exp(-pow((d-width*1.4)/maxf(width*.8,30),2))
			var back:float=exp(-pow((d-width*3)/maxf(width*1.3,60),2))
			land=lerpf(land,-settings.depth_variation*(.65+w[7]*.4),bed)
			land+=bank*settings.levee_height*(w[3]+w[7]*.6)
			land-=back*(w[3]+w[10]+w[4]*.5)*.9
			channel=maxf(channel,bed);flood=maxf(flood,fp);levee=maxf(levee,bank)
			# Side channel peels off and rejoins the SAME carrier at segment ends.
			var phase:float=fposmod(p.x+float(lane+j)*713,3200)/3200
			var split:float=pow(sin(phase*PI),2)*380
			var side:float=carrier.x+split*(1.0 if (lane+j)%2==0 else -1.0)
			var sd:float=absf(p.y-side)
			var sidebed:float=(1-smoothstep(22,65,sd))*smoothstep(0,.15,phase)*(1-smoothstep(.85,1,phase))*country*(w[6]+w[7]+w[3]*.6)
			land=lerpf(land,-settings.depth_variation*.55,clampf(sidebed,0,1));channel=maxf(channel,sidebed)
			# Rare abandoned bend: partial curved former channel with a dry neck.
			var segment:int=floori((p.x+float(lane+j)*713)/3200)
			if random(segment,lane+j,229)<.28:
				var ox:=Vector2((phase-.52)*3200/340,(p.y-carrier.x-430)/210)
				var od:float=absf(ox.length()-1)
				var neck:float=smoothstep(-.8,-.2,ox.x)
				var oxbow:float=(1-smoothstep(.12,.33,od))*neck*(w[3]+w[7]+w[10])*.9
				land=lerpf(land,-settings.depth_variation*.6,clampf(oxbow,0,1));basin=maxf(basin,oxbow);abandoned=maxf(abandoned,oxbow)
			deposition=maxf(deposition,fp*(.45+.3*sin(p.x/500+carrier.z*2))*(1-bed*.4))
	# Enclosed descriptors have their own level and a raised retaining rim.
	if w[8]+w[11]+w[2]+w[9]>.08:
		for site:Array in _pool_sites(Vector2i(floori(p.x/1800),floori(p.y/1800))):
			var v:Vector2=(p-(site[0] as Vector2)).rotated(site[3]);var radius:float=site[1]
			if v.length()>radius*1.4:continue
			var q:=Vector2(v.x/radius,v.y/(radius*site[2]))
			var contour:float=q.length()+sin(q.x*3+site[5]*9)*.11+sin(q.y*4)*.06
			var support:float=1-smoothstep(.82,1.25,contour)
			var bed:float=1-smoothstep(.3,.85,contour)
			var local_level:float=site[4]
			var bowl:float=local_level+2.4-bed*(2.4+settings.depth_variation*.55)
			var eligible:float=clampf(w[8]+w[11]+w[2]*.45+w[9]*.25,0,1)*(1-channel)
			var absolute_ground:float=lerpf(table+land,bowl,support*eligible)
			table=lerpf(table,local_level,support*eligible)
			land=absolute_ground-table
			basin=maxf(basin,bed*eligible);deposition=maxf(deposition,bed*eligible*.8)
	var rock:float=w[12]*smoothstep(-.05,.35,b)*.85
	land+=rock*(3+absf(b)*9)*(1-channel)
	land-=settings.erosion_intensity*channel*maxf(c,0)*.4
	land+=deposition*settings.sediment_deposition*.18
	var wet:float=clampf((1-smoothstep(-.3,2.8,land))*settings.water_table_influence+flood*.12,0,1)
	var peat:float=clampf((w[5]*.9+w[4]*.6+w[9]*.5+w[10]*.4)*(1-deposition*.5),0,1)
	var sediment:float=clampf(deposition+w[2]*.6+w[8]*.5+w[11]*.4,0,1)
	var id:int=0
	for i in range(1,15):
		if w[i]>w[id]:id=i
	return PackedFloat64Array([table+land,table,wet,peat,sediment,channel,basin,levee,raised,rock,float(id)/14,clampf(w[4]+w[5]*.7+w[10]*.6,0,1),abandoned,flood])
func _node(cell:Vector2i)->PackedFloat64Array:
	if _nodes.has(cell):return _nodes[cell]
	var value:PackedFloat64Array=_raw(Vector2(cell)*STEP)
	if _nodes.size()>=16384:_nodes.clear()
	_nodes[cell]=value;return value
func cubic(a:float,b:float,c:float,d:float,t:float)->float:
	return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))
func sample(x:float,z:float,publish:bool=true)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	if f==Vector2.ZERO:
		var value:PackedFloat64Array=_node(cell)
		if publish:state=value
		return value[0]
	var rows:=PackedFloat64Array();var waters:=PackedFloat64Array()
	for j in range(-1,3):
		var a:PackedFloat64Array=_node(cell+Vector2i(-1,j));var b:PackedFloat64Array=_node(cell+Vector2i(0,j));var c:PackedFloat64Array=_node(cell+Vector2i(1,j));var d:PackedFloat64Array=_node(cell+Vector2i(2,j))
		rows.append(cubic(a[0],b[0],c[0],d[0],f.x));waters.append(cubic(a[1],b[1],c[1],d[1],f.x))
	var h:float=cubic(rows[0],rows[1],rows[2],rows[3],f.y)
	if publish:
		var a:PackedFloat64Array=_node(cell);var b:PackedFloat64Array=_node(cell+Vector2i.RIGHT);var c:PackedFloat64Array=_node(cell+Vector2i.DOWN);var d:PackedFloat64Array=_node(cell+Vector2i.ONE)
		state=PackedFloat64Array();state.resize(14);state[0]=h;state[1]=cubic(waters[0],waters[1],waters[2],waters[3],f.y)
		for k in range(2,14):state[k]=clampf(lerpf(lerpf(a[k],b[k],f.x),lerpf(c[k],d[k],f.x),f.y),0,1)
		state[2]=clampf((1-smoothstep(-.3,2.8,h-state[1]))*settings.water_table_influence+state[5]*.12,0,1)
	return h

