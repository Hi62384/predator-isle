extends RefCounted
## Temperate geography, not recolored Jungle. Worker-owned canonical C1 field.
const NAMES=["Deciduous lowlands","Conifer uplands","Mixed woodland","Old-growth basin","Rolling woodland","Rocky woodland","Mountain forest","Sheltered valley","Riparian woodland","Open woodland meadow"]
const STEP:float=64
var settings:Resource
var seed_value:int
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var weights:=PackedFloat32Array()
var wetness:float=0
var drainage:float=0
var rock:float=0
var clearing:float=0
var conifer:float=0
var region:int=0
var river:float=0
var lake:float=0
func configure(config:Resource,world_seed:int)->void:
	settings=config;seed_value=world_seed
	for item in [[_macro,11301,1.0/3600,2],[_meso,11317,1.0/680,2],[_detail,11339,1.0/180,1]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.32
	_nodes.clear();_regions.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	var occurrence:Array=[settings.deciduous_frequency,settings.conifer_frequency,settings.mixed_frequency,settings.old_growth_frequency,.16,.12,settings.mountain_frequency,.12,.12,.12]
	var mass:float=0
	for value:float in occurrence:mass+=maxf(value,0)
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var roll:float=random(q.x,q.y,7)*mass;var id:int=9
			for i in range(10):
				roll-=occurrence[i]
				if roll<=0:id=i;break
			var d:float=p.distance_to(site);closest=minf(closest,d);sites.append([d,id])
	var result:=PackedFloat32Array();result.resize(10);var total:float=0
	for site:Array in sites:
		var amount:float=1-smoothstep(0,span*.17,float(site[0])-closest);result[site[1]]+=amount;total+=amount
	for i in range(10):result[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:PackedFloat32Array=_region_node(cell)
	if f==Vector2.ZERO:return a
	var b:PackedFloat32Array=_region_node(cell+Vector2i.RIGHT);var c:PackedFloat32Array=_region_node(cell+Vector2i.DOWN);var d:PackedFloat32Array=_region_node(cell+Vector2i.ONE)
	if a==b and a==c and a==d:return a
	var result:=PackedFloat32Array();result.resize(10)
	for i in range(10):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return result
func _raw(p:Vector2)->Vector4:
	var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var q:Vector2=p.rotated(-.61+float(seed_value%73)*.002)
	var across:float=fposmod(q.x+sin(q.y/3900)*950+a*480+6500,13000)-6500
	var ridge:float=exp(-pow(absf(across)/maxf(settings.valley_scale*.5,400),1.65))
	var saddles:float=.75+.15*sin(q.y/1800)+b*.25
	var mountain:float=settings.mountain_height*ridge*saddles
	var hollow:float=1-smoothstep(.03,.24,absf(b+a*.3))
	var low:float=1-settings.lowland_frequency*.6
	var rolling:float=(35+b*65+a*20)*settings.hill_frequency
	var h:float=w[0]*(22+a*12+b*5)*low+w[1]*(65+rolling*1.3+ridge*130)
	h+=w[2]*(35+rolling+a*10)+w[3]*(28+a*10+b*4+c*1.5)
	h+=w[4]*(55+rolling*2.5+ridge*65)+w[5]*(55+ridge*240+absf(b)*100+c*8*settings.ruggedness)
	h+=w[6]*(80+mountain-hollow*ridge*settings.ravine_depth*settings.erosion_strength)
	h+=w[7]*(40+mountain*.35-hollow*settings.ravine_depth*.4)+w[8]*(12+a*4+b*1.2)+w[9]*(25+a*12+b*3)
	var drain:float=clampf(hollow*(w[5]*.3+w[6]*.65+w[7])+w[8]*.7+w[3]*.25,0,1)
	var wet:float=clampf(.2+settings.wetness*.35+a*.1+drain*.3+w[3]*.12-ridge*w[6]*.12,.05,.9)
	var exposure:float=clampf(w[5]*.85+w[6]*ridge*.7+w[7]*.45+w[1]*.18,0,1)
	return Vector4(maxf(h,4),wet,drain,exposure)
func _node(cell:Vector2i)->Array:
	if _nodes.has(cell):return _nodes[cell]
	var p:=Vector2(cell)*STEP;var a:Vector4=_raw(p)
	var result:Array=[Vector4(a.x,(_raw(p+Vector2(16,0)).x-a.x)/16,(_raw(p+Vector2(0,16)).x-a.x)/16,a.y),Vector2(a.z,a.w)]
	if _nodes.size()>=16384:_nodes.clear()
	_nodes[cell]=result;return result
func hermite(a:float,b:float,da:float,db:float,t:float)->float:
	var t2:float=t*t;var t3:float=t2*t
	return (2*t3-3*t2+1)*a+(t3-2*t2+t)*da+(-2*t3+3*t2)*b+(t3-t2)*db
func sample(x:float,z:float,publish:bool=true)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:Array=_node(cell);var av:Vector4=a[0];var h:float=av.x;var wet:float=av.w;var surface:Vector2=a[1]
	if f!=Vector2.ZERO:
		var b:Array=_node(cell+Vector2i.RIGHT);var c:Array=_node(cell+Vector2i.DOWN);var d:Array=_node(cell+Vector2i.ONE)
		var bv:Vector4=b[0];var cv:Vector4=c[0];var dv:Vector4=d[0];var sx:float=f.x*f.x*(3-2*f.x)
		h=hermite(hermite(av.x,bv.x,av.y*STEP,bv.y*STEP,f.x),hermite(cv.x,dv.x,cv.y*STEP,dv.y*STEP,f.x),lerpf(av.z,bv.z,sx)*STEP,lerpf(cv.z,dv.z,sx)*STEP,f.y)
		wet=lerpf(lerpf(av.w,bv.w,f.x),lerpf(cv.w,dv.w,f.x),f.y);surface=(a[1] as Vector2).lerp(b[1],f.x).lerp((c[1] as Vector2).lerp(d[1],f.x),f.y)
	if publish:
		weights=region_weights(Vector2(x,z));region=0
		for i in range(1,10):
			if weights[i]>weights[region]:region=i
		wetness=wet;drainage=surface.x;rock=surface.y;river=0;lake=0
		conifer=clampf(weights[1]+weights[2]*.45+weights[6]*.5,0,1)
		var gap:float=clampf(_macro.get_noise_2d(x*1.9+2391,z*1.9-971)*.9+.5,0,1)
		clearing=clampf(weights[9]+(1-weights[9])*smoothstep(.55,.85,gap)*settings.clearing_frequency*2,0,1)
	return h
