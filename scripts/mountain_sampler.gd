extends RefCounted
## Geological ridge skeleton, canonical C1 height/water fields, worker-owned caches.
const NAMES=["Jagged alpine","Massive ranges","Rocky mountains","Ancient highlands","Glacial country","Granite massifs","Stratified mountains","Foothills","Alpine plateaus","Basin country","Deep valleys","Escarpments","Dry mountains","Scree highlands","Arete country","Meadow valleys"]
const STEP:float=32
var settings:Resource
var seed_value:int
var _host:WeakRef
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var _carriers:Dictionary={}
var _landmarks:Dictionary={}
var state:=PackedFloat64Array()
var profile:bool=false
var timings:Dictionary={}
func configure(config:Resource,world_seed:int,host:RefCounted)->void:
	settings=config;seed_value=world_seed;_host=weakref(host)
	for item in [[_macro,21301,1.0/8200,2],[_meso,21317,1.0/1400,2],[_detail,21339,1.0/settings.erosion_scale,2]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.32
	_nodes.clear();_regions.clear();_carriers.clear();_landmarks.clear();timings.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	var occurrence:Array=[.2,.12,.17,settings.highland_frequency,settings.glacial_frequency,.16,.14,.13,settings.highland_frequency*.6,settings.basin_frequency*.5,.15,.12,.13,.12,.12,.13]
	var mass:float=0
	for value:float in occurrence:mass+=maxf(value,0)
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var roll:float=random(q.x,q.y,7)*mass;var id:int=15
			for i in range(16):
				roll-=occurrence[i]
				if roll<=0:id=i;break
			var d:float=p.distance_to(site);closest=minf(closest,d);sites.append([d,id])
	var result:=PackedFloat32Array();result.resize(16);var total:float=0
	for site:Array in sites:
		var amount:float=1-smoothstep(0,span*.17,float(site[0])-closest);result[site[1]]+=amount;total+=amount
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
	for i in range(16):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return result


func _spacing()->float:
	var host:RefCounted=_host.get_ref()
	return 4000/maxf(host.settings.grass_river_frequency,.1)*settings.ridge_scale
func _carrier(x:float,lane:int)->Vector3:
	# Fractional probes must evaluate their own continuous river function,
	# not reuse another point rounded to the nearest metre.
	var exact:bool=x==floorf(x) and absf(x)<2000000000.0 and lane>-2000000000 and lane<2000000000
	var key:=Vector2i.ZERO
	if exact:
		key=Vector2i(int(x),lane)
		if _carriers.has(key):return _carriers[key]
	var host:RefCounted=_host.get_ref();var scale:float=settings.ridge_scale
	var base_spacing:float=_spacing()/scale
	var center:float=host._grass_river_center(x/scale,lane,base_spacing)*scale
	var slope:float=(host._grass_river_center((x+32)/scale,lane,base_spacing)-host._grass_river_center((x-32)/scale,lane,base_spacing))*scale/64
	var result:=Vector3(center,slope,0)
	if exact:
		if _carriers.size()>=2048:_carriers.clear()
		_carriers[key]=result
	return result
func water_potential(x:float)->float:
	# Finite watersheds drain AWAY from their high divide, toward either end.
	# An infinite bounded-height world cannot have one globally downhill river.
	var t:float=fposmod(x+float(seed_value%31)*139,18000)/18000
	return 120+260*pow(sin(t*PI),2)
func _sites(cell:Vector2i)->Array:
	if _landmarks.has(cell):return _landmarks[cell]
	var result:Array=[]
	for i in range(-1,2):
		var q:=cell+Vector2i(i,0);var r:float=random(q.x,q.y,251)
		var x:float=roundf((float(q.x)+.25+random(q.x,q.y,253)*.5)*settings.peak_spacing/STEP)*STEP
		var lo:Vector3=_carrier(x,q.y);var hi:Vector3=_carrier(x,q.y+1)
		result.append([x,(lo.x+hi.x)*.5,r,float(q.y)])
	if _landmarks.size()>=1024:_landmarks.clear()
	_landmarks[cell]=result;return result
func _raw(p:Vector2)->PackedFloat64Array:
	var tick:int=Time.get_ticks_usec() if profile else 0
	var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var spacing:float=_spacing();var lane:int=roundi(p.y/spacing)
	var valley_center:Vector3=_carrier(p.x,lane)
	# Check adjacent warped carriers rather than assuming unwarped nearest ownership.
	for k in [-1,1]:
		var other:Vector3=_carrier(p.x,lane+k)
		if absf(p.y-other.x)<absf(p.y-valley_center.x):valley_center=other
	var distance:float=absf(p.y-valley_center.x)/sqrt(1+valley_center.y*valley_center.y)
	var glacial:float=clampf((w[4]+w[9]*.45+w[14]*.65)*settings.glacial_influence,0,1)
	var ridge:float=0;var secondary:float=0;var peak:float=0;var height:float=0;var cirque:float=0;var tarn:float=0
	var width:float=settings.ridge_width*settings.belt_width
	var heights:Array=[1.05,1.55,.9,.48,1.15,1.05,.85,.25,.7,.7,1.15,.85,.85,.65,1.15,.65]
	var gain:float=0
	for i in range(16):gain+=w[i]*heights[i]
	for k in range(-1,2):
		var id:int=lane+k;var lower:Vector3=_carrier(p.x,id);var upper:Vector3=_carrier(p.x,id+1)
		var center:float=(lower.x+upper.x)*.5
		var across:float=p.y-center
		if absf(across)>spacing*.65:continue
		var shoulder:float=1-smoothstep(spacing*.42,spacing*.65,absf(across))
		var local_width:float=width*(1+w[3]*.85+w[1]*.35+w[8]*.5-w[14]*.4)
		var asym:float=.7+.6*smoothstep(-500,500,across+b*250)
		var d:float=absf(across)/maxf(local_width*asym,settings.cliff_width)
		var rounded:float=exp(-d*d*.75)
		var sharp:float=exp(-pow(d,settings.ridge_sharpness)*1.5)
		var shape:float=lerpf(sharp,rounded,clampf(w[3]+w[5]*.65+w[7]*.6+w[8]*.5,0,1))*shoulder
		var span:float=settings.peak_spacing
		var cell:=Vector2i(floori(p.x/span),id)
		var summits:float=0
		for site:Array in _sites(cell):
			var dx:float=absf(p.x-site[0])/(span*(.23+site[2]*.17))
			var prominence:float=exp(-pow(dx,1.6))*(.55+site[2]*.65)
			summits=maxf(summits,prominence)
			# Cirques belong to ridge shoulders below actual summit descriptors.
			if glacial>.03 and site[2]<.62:
				var side:float=-1 if random(floori(site[0]/span),id,257)<.5 else 1
				var v:=Vector2((p.x-site[0])/(500+site[2]*450),(p.y-center-side*local_width*.8)/(650+site[2]*350))
				var bowl:float=(1-smoothstep(.35,1.15,v.length()+sin(v.x*2)*.08))*glacial
				cirque=maxf(cirque,bowl)
				if site[2]<settings.lake_frequency:tarn=maxf(tarn,bowl)
		var core:float=shape*(.55+summits*.65)
		var branch_phase:float=fposmod(p.x-across*.4+b*160+float(id)*331,span)/span
		var branch_distance:float=minf(branch_phase,1-branch_phase)*span
		var branches:float=exp(-pow(branch_distance/maxf(150,span*.11),2))*shoulder*(1-smoothstep(local_width*.2,spacing*.6,absf(across)))
		branches*=settings.secondary_strength*settings.branching*(.3+.7*shape)
		var value:float=core*settings.mountain_height*gain
		value+=branches*settings.mountain_height*.22
		# Resistant shelves only in layered/escarpment country, with finite widths.
		var shelf:float=(1-smoothstep(settings.cliff_width,settings.cliff_width*2,absf(across)-local_width*.45))*(w[6]+w[11])*.22
		value+=shelf*settings.mountain_height*settings.cliff_frequency
		height=maxf(height,value);ridge=maxf(ridge,shape);secondary=maxf(secondary,branches);peak=maxf(peak,summits*shape)
	if profile:timings["ridge_us"]=timings.get("ridge_us",0)+Time.get_ticks_usec()-tick;tick=Time.get_ticks_usec()
	var water:float=water_potential(p.x)
	var valley_width:float=settings.valley_width*(1+w[15]+w[4]*.4-w[10]*.45)*(.85+.2*a)
	var v:float=1-smoothstep(valley_width*.2,valley_width*1.45,distance)
	var u:float=1-smoothstep(valley_width*.8,valley_width*1.65,distance)
	var valley:float=lerpf(v,u,glacial)
	var h:float=water+45+height+(a*18+b*12)*(1-valley*.8)
	var floor_height:float=water+8+b*3+absf(c)*2
	h=lerpf(h,floor_height,valley*settings.valley_depth)
	# Broad plateau and basin floors contrast with steep chains.
	h+=w[8]*(1-valley)*smoothstep(.1,.7,ridge)*180
	var incision:float=(1-smoothstep(.02,.22,absf(c+b*.25)))*ridge*(1-peak*.5)
	var erosion:float=incision*settings.erosion*settings.gully_strength
	h-=erosion*(55+w[12]*35+w[10]*30)*settings.ruggedness
	var apron:float=exp(-pow((distance-valley_width*1.8)/maxf(settings.talus_size,200),2))*(.35+ridge*.65)
	var scree:float=clampf(apron*(.4+w[13]+w[4]*.4+w[5]*.5)+erosion*.25,0,1)
	h+=apron*settings.weathering*35*(w[13]+w[5]*.7+w[11]*.5)
	var fan:float=(1-smoothstep(.05,.35,absf(b)))*apron*settings.erosion
	h+=fan*28*(1-valley*.4)
	var cirque_floor:float=water+settings.mountain_height*.32
	h=lerpf(h,minf(h,cirque_floor+8+c*3),cirque)
	var channel:float=1-smoothstep(settings.river_width*.4,settings.river_width*1.8,distance)
	var wet_country:float=1-w[12]*.95
	if settings.river_frequency>0:
		var wet:float=channel*smoothstep(0,.3,settings.river_frequency)*wet_country
		h=lerpf(h,water-2.5,wet)
	else:channel=0
	# Irregular valley lakes are descriptors tied to the same valley skeleton.
	var basin:float=0
	if settings.lake_frequency>0 and w[4]+w[9]+w[15]>.1:
		var segment:int=floori(p.x/6000)
		for j in [-1,0,1]:
			var r:float=random(segment+j,lane,271)
			if r>settings.lake_frequency*settings.basin_frequency:continue
			var x:float=roundf((float(segment+j)+.35+r*.4)*6000/STEP)*STEP
			var cy:float=_carrier(x,lane).x;var level:float=water_potential(x)+3
			var q:=Vector2((p.x-x)/(650+r*1000),(p.y-cy)/(220+r*450))
			var contour:float=q.length()+sin(q.x*2.4+r*7)*.12+sin(q.y*3)*.07
			var support:float=(1-smoothstep(.8,1.25,contour))*clampf(w[4]+w[9]+w[15],0,1)
			var bed:float=1-smoothstep(.25,.9,contour)
			h=lerpf(h,level+12-bed*(17+r*7),support)
			water=lerpf(water,level,support);basin=maxf(basin,bed*support)
	# Protected elevated tarn, behind the cirque lip; no waterfall mesh is implied.
	if tarn>.1 and settings.lake_frequency>.1:
		var bowl:float=smoothstep(.45,.8,tarn)
		var support:float=smoothstep(.3,.7,tarn)
		var level:float=cirque_floor+10
		h=lerpf(h,level+5-bowl*8,support)
		water=lerpf(water,level,support);basin=maxf(basin,bowl)
	var rock:float=clampf(ridge*.7+peak*.3+erosion*.35+(w[5]+w[6]+w[11])*.3-valley*.25,0,1)
	var wetness:float=clampf(valley*.45+channel*.5+basin*.6+cirque*.25-w[12]*.35,0,1)
	var id:int=0
	for i in range(1,16):
		if w[i]>w[id]:id=i
	if profile:timings["valley_water_erosion_us"]=timings.get("valley_water_erosion_us",0)+Time.get_ticks_usec()-tick
	return PackedFloat64Array([h,water,rock,scree,float(id)/15,glacial,valley,ridge,secondary,erosion,wetness,peak,basin,channel,cirque,fan,1-peak,w[6]+w[11]])
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
		state=PackedFloat64Array();state.resize(18);state[0]=h;state[1]=cubic(waters[0],waters[1],waters[2],waters[3],f.y)
		for k in range(2,18):state[k]=clampf(lerpf(lerpf(a[k],b[k],f.x),lerpf(c[k],d[k],f.x),f.y),0,1)
	return h
