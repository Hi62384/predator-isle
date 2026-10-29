extends RefCounted
## Independent Savanna geography on the established bounded canonical C1 lattice.
const NAMES=["Golden plains","Rolling savanna","Dry rocky savanna","Lush seasonal savanna","Rugged hills","Granite kopje country","Savanna highlands","Dry river valleys","Seasonal floodplain","Semi-arid savanna","Laterite uplands","Rocky escarpments","Basin country"]
const STEP:float=32
var settings:Resource
var seed_value:int
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var _kopje_cache:Dictionary={}
var weights:=PackedFloat32Array()
var wetness:float=0
var drainage:float=0
var rock:float=0
var aridity:float=0
var laterite:float=0
var soil:float=0
var erosion:float=0
var region:int=0
var river:float=0
var lake:float=0
var water:float=0
func configure(config:Resource,world_seed:int)->void:
	settings=config;seed_value=world_seed
	for item in [[_macro,17301,1.0/3600,2],[_meso,17317,1.0/680,2],[_detail,17339,1.0/180,1]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.32
	_nodes.clear();_regions.clear();_kopje_cache.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	var occurrence:Array=[settings.plains_frequency,settings.rolling_frequency,settings.rocky_frequency,.1,settings.rocky_frequency*.65,.14,settings.highland_frequency,.13,.1,.12,.12,settings.highland_frequency*.7,settings.basin_frequency]
	var mass:float=0
	for value:float in occurrence:mass+=maxf(value,0)
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var roll:float=random(q.x,q.y,7)*mass;var id:int=12
			for i in range(13):
				roll-=occurrence[i]
				if roll<=0:id=i;break
			var d:float=p.distance_to(site);closest=minf(closest,d);sites.append([d,id])
	var result:=PackedFloat32Array();result.resize(13);var total:float=0
	for site:Array in sites:
		var amount:float=1-smoothstep(0,span*.17,float(site[0])-closest);result[site[1]]+=amount;total+=amount
	for i in range(13):result[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=result;return result
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:PackedFloat32Array=_region_node(cell)
	if f==Vector2.ZERO:return a
	var b:PackedFloat32Array=_region_node(cell+Vector2i.RIGHT);var c:PackedFloat32Array=_region_node(cell+Vector2i.DOWN);var d:PackedFloat32Array=_region_node(cell+Vector2i.ONE)
	if a==b and a==c and a==d:return a
	var result:=PackedFloat32Array();result.resize(13)
	for i in range(13):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(c[i],d[i],f.x),f.y)
	return result
func _kopje_sites(cell:Vector2i)->Array:
	if _kopje_cache.has(cell):return _kopje_cache[cell]
	var sites:Array=[]
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=cell+Vector2i(x,z);var r:float=random(q.x,q.y,151)
			if r>settings.kopje_frequency:continue
			var center:Vector2=(Vector2(q)+Vector2(.2+random(q.x,q.y,153)*.6,.2+random(q.x,q.y,157)*.6))*1600
			sites.append([center,r,random(q.x,q.y,159)*TAU,settings.kopje_size*(.7+r)])
	if _kopje_cache.size()>=1024:_kopje_cache.clear()
	_kopje_cache[cell]=sites;return sites
func _kopjes(p:Vector2)->Vector3:
	if settings.kopje_frequency<=0:return Vector3.ZERO
	var cell:=Vector2i(floori(p.x/1600),floori(p.y/1600));var height:float=0;var stone:float=0;var apron:float=0
	for site:Array in _kopje_sites(cell):
		var r:float=site[1];var scale:float=site[3];var local:Vector2=(p-(site[0] as Vector2)).rotated(site[2])
		if local.length()>scale*2.3:continue
		var mass:float=0
		for k in range(3):
			var radius:float=scale*(.75-float(k)*.12)*(.9+.18*sin(r*19+float(k)*7))
			var offset:Vector2=[Vector2(-.6,-.18),Vector2(.48,.32),Vector2(.12,-.64)][k]*scale
			offset+=Vector2(sin(r*39+float(k)*2.7),cos(r*23+float(k)*3.7))*scale*.18
			var d:float=Vector2((local.x-offset.x)/radius,(local.y-offset.y)/(radius*(.65+r*.3))).length()
			d+=sin(local.y/(scale*.4)+r*19+float(k))*.06
			var cap:float=(1-smoothstep(.2,1.08,d))*(.95+.05*sqrt(maxf(1-d*d,0)))
			var dome:float=cap*(80+r*100)*(1-float(k)*.13)*(.9+.2*cos(r*37+float(k)*5))
			var joint:float=(1-smoothstep(18,65,absf(local.x-local.y*.28-scale*(r-.2))))*smoothstep(.15,.65,d)
			var shelf:float=1-settings.kopje_ruggedness*.23*joint
			mass=maxf(mass,dome*shelf)
		height=maxf(height,mass);stone=maxf(stone,smoothstep(8,45,mass));apron=maxf(apron,(1-smoothstep(scale,scale*1.9,local.length()))*.6)
	return Vector3(height,stone,apron)
func _raw(p:Vector2)->Vector4:
	var w:PackedFloat32Array=region_weights(p)
	var a:float=_macro.get_noise_2d(p.x,p.y);var b:float=_meso.get_noise_2d(p.x,p.y);var c:float=_detail.get_noise_2d(p.x,p.y)
	var q:Vector2=p.rotated(.43+float(seed_value%71)*.002)
	var across:float=fposmod(q.x+sin(q.y/4300)*1200+a*600+7000,14000)-7000
	var belt:float=exp(-pow(absf(across)/1500,1.6))
	var peaks:float=.78+.16*sin(q.y/2200)+b*.22
	var ridge:float=belt*settings.mountain_height*peaks
	var secondary:float=(1-smoothstep(.02,.4,absf(b)))*belt*settings.ridge_intensity*100
	var hollow:float=1-smoothstep(.025,.24,absf(b+a*.2))
	var incision:float=hollow*belt*settings.erosion_intensity*settings.drainage_strength*70
	var hills:float=40+b*90+a*30+sin(q.y/1700+a)*13
	var table:float=smoothstep(-.18,.3,a+b*.35)
	var edge:float=smoothstep(.1,.8,table)*(1-smoothstep(.8,1,table))
	var kopje:=Vector3.ZERO
	if w[5]+w[2]+w[9]>.005:kopje=_kopjes(p)
	var h:float=w[0]*(24+a*11+b*3+c*.5-hollow*1.8)
	h+=w[1]*(35+hills*1.3)+w[2]*(45+hills*.7+absf(b)*70+kopje.x*.2)
	h+=w[3]*(30+a*14+b*9)+w[4]*(65+ridge*.45+secondary-incision*.8)
	h+=w[5]*(24+a*8+b*4+kopje.x)
	h+=w[6]*(110+ridge+secondary-incision)
	h+=w[7]*(32+ridge*.18-hollow*22*settings.drainage_strength)
	h+=w[8]*(9+a*3+b*.8)+w[9]*(25+a*18+b*5+kopje.x*.12)
	h+=w[10]*(48+table*100+b*14-hollow*18*settings.erosion_intensity)
	h+=w[11]*(45+table*310+b*18+ridge*.2-incision*.5)
	h+=w[12]*(18+a*6+b*2-hollow*5)
	var drain:float=clampf(hollow*(w[0]*.28+w[1]*.32+w[4]*.6+w[6]+w[7]*.8+w[10]*.3)+w[8]*.75+w[12]*.4,0,1)
	var wet:float=clampf(.18+w[3]*.45+w[8]*.4+w[12]*.22+drain*.45-w[0]*a*.25-w[9]*.14-belt*w[6]*.08,.03,.85)
	var exposure:float=clampf(w[2]*.6+w[4]*belt*.8+w[5]*kopje.y+w[6]*belt*.9+w[11]*edge*.95+kopje.z*w[5]*.25,0,1)
	return Vector4(maxf(h,3),wet,drain,exposure)
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
		for i in range(1,13):
			if weights[i]>weights[region]:region=i
		wetness=wet;drainage=surface.x;rock=surface.y;river=0;lake=0
		aridity=clampf(.6+weights[9]*.3-weights[3]*.35-weights[8]*.3-weights[12]*.15-drainage*.18,0,1)
		var ridge_soil:float=smoothstep(.05,.3,_meso.get_noise_2d(x,z))
		laterite=clampf(weights[10]+weights[2]*.35+weights[4]*.25+weights[11]*.2+weights[0]*ridge_soil*.3,0,1)
		soil=clampf(.12+laterite*.45+weights[9]*.3+drainage*.15+weights[0]*ridge_soil*.15,0,1)
		erosion=clampf(drainage*(weights[4]+weights[6]+weights[7]+weights[10])*.8,0,1)
	return h
