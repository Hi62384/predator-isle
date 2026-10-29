extends RefCounted
## Worker-owned Jungle geography. Shared canonical Hermite field, bounded caches.
const NAMES=["Lowland rainforest","Rolling jungle","Rugged jungle hills","Jungle foothills","Jungle mountains","River rainforest","Floodplain jungle","Rocky jungle","Tropical karst","Jungle plateau","Jungle gorge","Humid basin","Upland rainforest"]
const STEP:float=64
var settings:JungleSettings
var seed_value:int
var _macro:=FastNoiseLite.new()
var _meso:=FastNoiseLite.new()
var _structure:=FastNoiseLite.new()
var _nodes:Dictionary={}
var _regions:Dictionary={}
var wetness:float
var drainage:float
var rock:float
var region:int
var river:float=0
var lake:float=0
var weights:=PackedFloat32Array()
func configure(config:JungleSettings,world_seed:int)->void:
	settings=config;seed_value=world_seed
	for item in [[_macro,9011,1.0/4200,2],[_meso,9031,1.0/850,2],[_structure,9041,1.0/2600,1]]:
		var n:FastNoiseLite=item[0];n.seed=world_seed+item[1];n.frequency=item[2];n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_type=FastNoiseLite.FRACTAL_FBM;n.fractal_octaves=item[3];n.fractal_gain=.35
	_nodes.clear();_regions.clear()
func random(x:int,z:int,salt:int)->float:
	var h:int=(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0
func _region_node(cell:Vector2i)->PackedFloat32Array:
	if _regions.has(cell):return _regions[cell]
	var p:=Vector2(cell)*512;var span:float=settings.region_metres
	var center:=Vector2i(floori(p.x/span),floori(p.y/span));var sites:Array=[];var closest:float=INF
	for z in range(-1,2):
		for x in range(-1,2):
			var q:=center+Vector2i(x,z);var site:Vector2=(Vector2(q)+Vector2(.15+random(q.x,q.y,3)*.7,.15+random(q.x,q.y,5)*.7))*span
			var r:float=random(q.x,q.y,7);var id:int
			var low:float=settings.lowland_frequency;var mountain:float=settings.mountain_frequency;var plateau:float=settings.plateau_frequency
			var total:float=maxf(low+mountain+plateau+.47,1);r*=total
			if r<low:id=0
			elif r<low+mountain:id=4
			elif r<low+mountain+plateau:id=9
			else:
				var others:Array=[1,2,3,5,6,7,8,10,11,12];id=others[clampi(int((r-low-mountain-plateau)/maxf(total-low-mountain-plateau,.001)*10),0,9)]
			var distance:float=p.distance_to(site);closest=minf(closest,distance);sites.append([distance,id])
	var weights:=PackedFloat32Array();weights.resize(13);var total:float=0
	for site:Array in sites:
		var weight:float=1-smoothstep(0,span*.20,float(site[0])-closest);weights[site[1]]+=weight;total+=weight
	for i in range(13):weights[i]/=maxf(total,.001)
	if _regions.size()>=2048:_regions.clear()
	_regions[cell]=weights;return weights
func region_weights(p:Vector2)->PackedFloat32Array:
	var q:Vector2=p/512;var c:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(c)
	var a:PackedFloat32Array=_region_node(c)
	if f==Vector2.ZERO:return a
	var b:PackedFloat32Array=_region_node(c+Vector2i.RIGHT);var d:PackedFloat32Array=_region_node(c+Vector2i.DOWN);var e:PackedFloat32Array=_region_node(c+Vector2i.ONE)
	if a==b and a==d and a==e:return a
	var result:=PackedFloat32Array();result.resize(13)
	for i in range(13):result[i]=lerpf(lerpf(a[i],b[i],f.x),lerpf(d[i],e[i],f.x),f.y)
	return result
func _raw(p:Vector2)->Vector4:
	var w:PackedFloat32Array=region_weights(p)
	var macro:float=_macro.get_noise_2d(p.x,p.y);var meso:float=_meso.get_noise_2d(p.x,p.y)
	var q:Vector2=p.rotated(.43+float(seed_value%97)*.004)
	var structure:float=_structure.get_noise_2d(q.x*.75,q.y*1.4)
	var across:float=fposmod(q.y+sin(q.x/4700)*750+macro*500+7000,14000)-7000
	var ridge:float=exp(-pow(absf(across)/1500,1.45))
	var hills:float=(.5+meso*.65)*settings.hill_density
	var mountain:float=settings.mountain_height*ridge*(.7+structure*.45)
	mountain+=pow(1-absf(structure),4)*ridge*settings.mountain_height*.15*settings.ruggedness
	var gully:float=(1-smoothstep(.025,.16,absf(meso+structure*.2)))*settings.gully_frequency
	var incision:float=gully*ridge*settings.erosion_strength*settings.valley_depth
	var karst:float=pow(1-absf(structure),5)*330+meso*20
	var plateau:float=smoothstep(-.13,.18,macro)*300+meso*9
	var gorge:float=1-smoothstep(.04,.30,absf(structure))
	var h:float=w[0]*(24+macro*9+meso*1.6)+w[1]*(40+hills*95)+w[2]*(65+hills*200+ridge*75)
	h+=w[3]*(65+mountain*.45)+w[4]*(70+mountain-incision)+w[5]*(15+macro*5+meso*2)
	h+=w[6]*(9+macro*3+meso*.6)+w[7]*(65+mountain*.55+structure*35)
	h+=w[8]*(45+karst)+w[9]*(65+plateau)+w[10]*(80+mountain*.4-gorge*settings.valley_depth)
	h+=w[11]*(16+macro*5+meso*1.5)+w[12]*(130+hills*90+ridge*120)
	h=maxf(h,3)
	var drain:float=clampf(gully*(w[2]+w[3]+w[4])+gorge*w[10]+w[5]*.4+w[6]*.65+w[11]*.5,0,1)
	var wet:float=clampf(.35+(macro*.2+meso*.1)*settings.wetness_variation+drain*.45+(w[0]+w[11])*.15-ridge*(w[4]+w[7])*.2,.1,.95)
	var exposed:float=clampf(w[7]*.7+w[8]*.85+w[4]*.55+w[10]*.6+w[9]*.45+w[2]*.2,0,1)
	return Vector4(h,wet,drain,exposed)
func _node(c:Vector2i)->Array:
	if _nodes.has(c):return _nodes[c]
	var p:=Vector2(c)*STEP;var a:Vector4=_raw(p)
	var dx:float=(_raw(p+Vector2(16,0)).x-a.x)/16;var dz:float=(_raw(p+Vector2(0,16)).x-a.x)/16
	var node:Array=[Vector4(a.x,dx,dz,a.y),Vector2(a.z,a.w)]
	if _nodes.size()>=16384:_nodes.clear()
	_nodes[c]=node;return node
func hermite(a:float,b:float,da:float,db:float,t:float)->float:
	var t2:float=t*t;var t3:float=t2*t
	return (2*t3-3*t2+1)*a+(t3-2*t2+t)*da+(-2*t3+3*t2)*b+(t3-t2)*db
func sample(x:float,z:float,publish:bool=true)->float:
	var q:=Vector2(x,z)/STEP;var cell:=Vector2i(floori(q.x),floori(q.y));var f:Vector2=q-Vector2(cell)
	var a:Array=_node(cell);var av:Vector4=a[0]
	var height:float=av.x;var wet:float=av.w;var surface:Vector2=a[1]
	if f!=Vector2.ZERO:
		var b:Array=_node(cell+Vector2i.RIGHT);var c:Array=_node(cell+Vector2i.DOWN);var d:Array=_node(cell+Vector2i.ONE)
		var bv:Vector4=b[0];var cv:Vector4=c[0];var dv:Vector4=d[0];var sx:float=f.x*f.x*(3-2*f.x)
		height=hermite(hermite(av.x,bv.x,av.y*STEP,bv.y*STEP,f.x),hermite(cv.x,dv.x,cv.y*STEP,dv.y*STEP,f.x),lerpf(av.z,bv.z,sx)*STEP,lerpf(cv.z,dv.z,sx)*STEP,f.y)
		wet=lerpf(lerpf(av.w,bv.w,f.x),lerpf(cv.w,dv.w,f.x),f.y)
		surface=(a[1] as Vector2).lerp(b[1],f.x).lerp((c[1] as Vector2).lerp(d[1],f.x),f.y)
	if publish:
		wetness=wet;drainage=surface.x;rock=surface.y;river=0;lake=0
		weights=region_weights(Vector2(x,z));region=0
		for i in range(1,13):
			if weights[i]>weights[region]:region=i
	return height
