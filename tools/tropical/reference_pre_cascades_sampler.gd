extends RefCounted
## Open humid island geography, not a Jungle clone. Fixed world lattice at every LOD.
const NAMES=["Coastal lowland","Lush plain","Rolling hills","Rugged hills","Rocky highland","Mountain belt","River valley","Humid basin","Lake country","Ancient volcanic highland","Limestone highland","Plateau country","Ravine country","Coastal bluff","Uplifted terrace","Weathered escarpment"]
const STEP:float=16
const CHANNELS:int=16
var settings:Resource
var _host:WeakRef
var seed_value:int
var _macro:=FastNoiseLite.new()
var _hills:=FastNoiseLite.new()
var _weather:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var _carriers:Dictionary={}
var _structural_nodes:Dictionary={}
## height, water, moisture, region, rock, erosion, valley, ridge, stream, lake, red soil, soil depth.
var state:=PackedFloat64Array()
var profile:bool=false
var timings:Dictionary={}
func configure(config:Resource,world_seed:int,host:RefCounted)->void:
	settings=config;seed_value=world_seed;_host=weakref(host)
	for item in [[_macro,24101,1.0/6500,2],[_hills,24117,1.0/maxf(settings.hill_width,200),2],[_weather,24139,1.0/350,2]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.35
	_nodes.clear();_regions.clear();_carriers.clear();_structural_nodes.clear();timings.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=maxf(settings.region_metres,1000)
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var closest:float=INF;var sites:Array=[]
	var occurrence:Array=[settings.lowland_frequency*.35,settings.lowland_frequency,settings.hill_frequency,settings.hill_frequency*.45,settings.rocky_frequency,settings.mountain_frequency,.3,settings.basin_frequency,.25,settings.highland_frequency*.6,settings.rocky_frequency*.4,settings.plateau_frequency,.15,.12,.12,settings.highland_frequency*.3]
	var mass:float=0
	for v:float in occurrence:mass+=maxf(v,0)
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var roll:float=random(q.x,q.y,7)*mass;var id:int=1
			if mass>0:
				for i in range(16):
					roll-=maxf(occurrence[i],0)
					if roll<=0:id=i;break
			# Coastal provinces belong to island margins, not arbitrary inland sites.
			if id==0 or id==13 or id==14:
				var host:RefCounted=_host.get_ref()
				var coast_distance:float=absf(host._island_mask(site.x,site.y)*host.settings.island_size*.5)
				if coast_distance>6000:id=1 if id==0 else (4 if id==13 else 11)
			var d:float=p.distance_to(site);closest=minf(closest,d);sites.append([d,id])
	var result:=PackedFloat32Array();result.resize(16);var total:float=0
	for site:Array in sites:
		var amount:float=1-smoothstep(0,span*.18,float(site[0])-closest);result[site[1]]+=amount;total+=amount
	for i in range(16):result[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:PackedFloat32Array=_region_node(cell)
	if f==Vector2.ZERO:return a
	var b:PackedFloat32Array=_region_node(cell+Vector2i.RIGHT);var c:PackedFloat32Array=_region_node(cell+Vector2i.DOWN);var d:PackedFloat32Array=_region_node(cell+Vector2i.ONE)
	if a==b and a==c and a==d:return a
	var result:=PackedFloat32Array();result.resize(16)
	f=Vector2(smoothstep(0,1,f.x),smoothstep(0,1,f.y))
	for i in range(16):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return result
func _spacing()->float:
	return 4000/maxf(_host.get_ref().settings.grass_river_frequency,.01)
func _carrier(x:float,lane:int)->Vector3:
	# Cache only exact lattice X, never round fractional calls into another field.
	var key:=Vector2i(int(x),lane)
	var exact:bool=x==floorf(x) and absf(x)<2000000000
	if exact and _carriers.has(key):return _carriers[key]
	var host:RefCounted=_host.get_ref();var result:Vector3=host._river_column(x,lane,_spacing())
	if exact:
		if _carriers.size()>=2048:_carriers.clear()
		_carriers[key]=result
	return result
func water_potential(x:float)->float:
	# Finite catchments, downhill away from each divide. No globally downhill infinite river.
	var t:float=fposmod(x+float(seed_value%31)*139,18000)/18000
	return 22+110*pow(sin(t*PI),2)
func _structural_node(index:int,lane:int)->float:
	var key:=Vector2i(index,lane)
	if _structural_nodes.has(key):return _structural_nodes[key]
	var host:RefCounted=_host.get_ref()
	var value:float=host._grass_river_center(float(index)*2048,lane,_spacing())
	if _structural_nodes.size()>=2048:_structural_nodes.clear()
	_structural_nodes[key]=value;return value
func _structural_center(x:float,lane:int)->float:
	# Fixed broad carrier, never a mesh-LOD filter. The fine inherited river
	# meanders remain in the channel; they must not corrugate entire mountains.
	var q:float=x/2048;var index:int=floori(q)
	return cubic(_structural_node(index-1,lane),_structural_node(index,lane),_structural_node(index+1,lane),_structural_node(index+2,lane),q-index)
func _raw(p:Vector2)->PackedFloat64Array:
	var tick:int=Time.get_ticks_usec() if profile else 0
	var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_hills.get_noise_2d(p.x,p.y);var c:float=_weather.get_noise_2d(p.x,p.y)
	var spacing:float=_spacing();var near:=Vector3.ZERO
	# carrier.z is width variation, not an owner ID.
	var nearest_lane:int=roundi(p.y/spacing)
	var best:float=INF
	for k in range(-1,2):
		var id:int=roundi(p.y/spacing)+k;var candidate:Vector3=_carrier(p.x,id);var d:float=absf(p.y-candidate.x)
		if d<best:best=d;near=candidate;nearest_lane=id
	var channel_distance:float=best/sqrt(1+near.y*near.y)
	# A first-order perpendicular estimate is useful only close to a channel.
	# Applying its rapidly changing slope normalization hundreds of metres away
	# made valley widths pulse and produced comb-like bands in native review.
	var distance:float=absf(p.y-_structural_center(p.x,nearest_lane))
	var calm:float=clampf(w[0]+w[1]+w[6]*.7+w[7]*.8+w[8]*.65,0,1)
	var rugged:float=clampf(w[3]+w[4]+w[5]+w[9]+w[10]*.8+w[12]+w[13]*.6+w[15],0,1)
	var water:float=water_potential(p.x)
	var h:float=water+30+a*18+(b*.5+.25)*settings.hill_height*(1-calm)*(1-rugged*.3)
	var ridge:float=0;var branches:float=0
	if rugged>.001:
		for k in [-1,0]:
			var id:int=nearest_lane+k
			var across:float=p.y-(_structural_center(p.x,id)+_structural_center(p.x,id+1))*.5
			var width:float=maxf(500,settings.hill_width*(.6+w[9]*.6+w[4]*.2-w[10]*.25))
			var shape:float=exp(-pow(absf(across)/(width*(.9+b*.2)),1.8))
			var segment:int=floori(p.x/4000);var summits:float=0
			for j in range(-1,2):
				var r:float=random(segment+j,id,101);var x:float=(segment+j+.2+r*.6)*4000
				summits=maxf(summits,exp(-pow((p.x-x)/(850+r*900),2))*(.55+r*.55))
			var phase:float=fposmod(p.x-across*.5+b*180+float(id)*317,2100)
			var branch:float=exp(-pow(minf(phase,2100-phase)/220,2))*shape*(1-smoothstep(100,600,absf(across)))
			branches=maxf(branches,branch);ridge=maxf(ridge,shape*(.45+summits*.65))
		var relief:float=settings.hill_height*(w[3]*1.1+w[4]*1.9+w[9]*2.6+w[10]*1.6+w[12]*1.8+w[13]+w[15]*1.7)+settings.mountain_height*w[5]
		h+=(ridge+branches*.14)*relief*settings.ridge_strength
	var valley_width:float=settings.valley_width*(1+w[6]*.8+w[7]*.5-w[12]*.65)
	var valley:float=1-smoothstep(40,valley_width,distance)
	h=lerpf(h,water+5+b*2,valley*settings.valley_depth)
	var erosion:float=(1-smoothstep(.025,.19,absf(c+b*.15)))*ridge*(1-valley*.8)*rugged*settings.erosion
	h-=erosion*(35+settings.hill_height*.12)*settings.gullies
	# Plateau shelves are regional, finite-width and weathered; no vertical heightfield jumps.
	var shelf:float=smoothstep(-.08,.17,b+a*.3)
	h+=shelf*(w[11]*150+w[14]*65+w[15]*120)*(1-valley)*settings.weathering
	var stream:float=0;var lake:float=0
	var channel:float=0
	var rivers:bool=settings.river_frequency>0 and _host.get_ref().settings.grass_river_frequency>0 and random(nearest_lane,0,139)<=settings.river_frequency
	if rivers:
		var width:float=settings.river_width*(.7+w[6]+w[8]*.35)*(1+near.z*.2)
		var river_bank:float=1-smoothstep(width*1.8,width*1.8+maxf(150,maxf(h-water,0)/.45),best)
		h=lerpf(h,minf(h,water+5),river_bank)
		channel=(1-smoothstep(width*.4,width*1.8,channel_distance))
		h=lerpf(h,water-3,channel)
		if settings.stream_frequency>0:
			var span:float=spacing*.6;var segment:int=floori(p.x/span)
			for j in range(-1,2):
				var r:float=random(segment+j,nearest_lane,131)
				if r>settings.stream_frequency:continue
				var t:float=(p.x-(segment+j+.15+r*.3)*span)/(span*.7)
				if t<=0 or t>=1:continue
				var side:float=-1 if random(segment+j,nearest_lane,137)<.5 else 1
				var across:float=absf(p.y-near.x-side*spacing*.22*t*t)
				var support:float=smoothstep(0,.05,t)*(1-smoothstep(.7,1,t))
				var grade:float=water+t*t*(35+r*40)
				# A small tributary needs a broad valley through high relief. A fixed
				# 120 m cut produced enormous heightfield walls in native review.
				var bank_width:float=maxf(150,maxf(h-grade,0)/.45)
				var bed:float=(1-smoothstep(8,35,across))*support
				var bank:float=(1-smoothstep(35,bank_width,across))*support
				h=lerpf(h,minf(h,grade+5),bank);h=lerpf(h,grade-1.8,bed)
				water=lerpf(water,grade,bank);stream=maxf(stream,bed);valley=maxf(valley,bank)
				# Occasional retained pools belong to real tributary descriptors.
				# Their support is bounded; no full-world search or circular scatter.
				if r<settings.basin_frequency*settings.stream_frequency and absf(t-.55)<.4:
					var cx:float=(segment+j+.15+r*.3)*span+.55*span*.7
					var cy:float=_carrier(cx,nearest_lane).x+side*spacing*.22*.55*.55
					var q:=Vector2((p.x-cx)/minf(90+r*180,span*.16),(p.y-cy)/(45+r*100))
					var contour:float=q.length()+sin(q.x*2.7+r*11)*.1
					var pool:float=1-smoothstep(.5,1.25,contour);var depth:float=1-smoothstep(.25,.8,contour)
					var level:float=water_potential(cx)+.55*.55*(35+r*40)
					h=lerpf(h,level+3-depth*7,pool);water=lerpf(water,level,pool);lake=maxf(lake,pool*depth)
	if settings.lake_frequency>0 and settings.basin_frequency>0 and w[7]+w[8]+w[6]>.1:
		var segment:int=floori(p.x/6000)
		for j in range(-1,2):
			var r:float=random(segment+j,nearest_lane,151)
			if r>settings.lake_frequency*settings.basin_frequency:continue
			var x:float=roundf((segment+j+.25+r*.5)*6000/STEP)*STEP;var center:float=_carrier(x,nearest_lane).x
			var q:=Vector2((p.x-x)/(450+r*1000),(p.y-center)/(180+r*450))
			var contour:float=q.length()+sin(q.x*2.4+r*8)*.1+sin(q.y*3)*.07
			var support:float=(1-smoothstep(.85,1.45,contour))*clampf(w[7]+w[8]+w[6],0,1)
			var bed:float=1-smoothstep(.3,1.0,contour);var level:float=water_potential(x)+3
			h=lerpf(h,level+12-bed*(20+r*10),support);water=lerpf(water,level,support);lake=maxf(lake,bed*support)
	var wet:float=clampf(.25+valley*.45+maxf(channel,stream)*.3+lake*.4+w[7]*.2+w[6]*.1-ridge*.1,0,1)
	var rock:float=clampf(rugged*.3+ridge*.4+erosion*.4+(w[4]+w[10]+w[15])*.2-valley*.3,0,1)
	var red:float=clampf(w[9]+w[3]*.6+w[15]*.5+erosion*.4,0,1)
	var id:int=0
	for i in range(1,16):
		if w[i]>w[id]:id=i
	if profile:timings["raw_us"]=timings.get("raw_us",0)+Time.get_ticks_usec()-tick
	return PackedFloat64Array([h,water,wet,float(id)/15,rock,erosion,valley,clampf(ridge,0,1),maxf(channel,stream),lake,red,1-rock,stream,channel,shelf,branches])
func _node(cell:Vector2i)->PackedFloat64Array:
	if _nodes.has(cell):return _nodes[cell]
	var v:PackedFloat64Array=_raw(Vector2(cell)*STEP)
	if _nodes.size()>=16384:_nodes.clear()
	_nodes[cell]=v;return v
func cubic(a:float,b:float,c:float,d:float,t:float)->float:
	return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))
func sample(x:float,z:float,publish:bool=true)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	if f==Vector2.ZERO:
		var v:PackedFloat64Array=_node(cell)
		if publish:state=v
		return v[0]
	var rows:=PackedFloat64Array();var waters:=PackedFloat64Array()
	for j in range(-1,3):
		var a:PackedFloat64Array=_node(cell+Vector2i(-1,j));var b:PackedFloat64Array=_node(cell+Vector2i(0,j));var c:PackedFloat64Array=_node(cell+Vector2i(1,j));var d:PackedFloat64Array=_node(cell+Vector2i(2,j))
		rows.append(cubic(a[0],b[0],c[0],d[0],f.x));waters.append(cubic(a[1],b[1],c[1],d[1],f.x))
	var h:float=cubic(rows[0],rows[1],rows[2],rows[3],f.y)
	if publish:
		var a:PackedFloat64Array=_node(cell);var b:PackedFloat64Array=_node(cell+Vector2i.RIGHT);var c:PackedFloat64Array=_node(cell+Vector2i.DOWN);var d:PackedFloat64Array=_node(cell+Vector2i.ONE)
		state=PackedFloat64Array();state.resize(CHANNELS);state[0]=h;state[1]=cubic(waters[0],waters[1],waters[2],waters[3],f.y)
		for k in range(2,CHANNELS):state[k]=clampf(lerpf(lerpf(a[k],b[k],f.x),lerpf(c[k],d[k],f.x),f.y),0,1)
	return h
