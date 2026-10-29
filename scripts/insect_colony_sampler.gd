extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Cathedral territory","Ant earthworks","Magnetic clay mounds","Dome nest plains","Abandoned colony","Rocky colony highlands"]
func satellites(d:Dictionary)->Array[Vector2]:
	var sites:Array[Vector2]=[]
	for i in range(4):
		var a:float=d.angle+i*1.57+.25*sin(i*7+d.age);sites.append(d.position+Vector2(cos(a),sin(a))*d.radius*(.55+float(i)*.17))
	return sites
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var d:Dictionary=nearby(p,2100*settings.feature_scale);var q:Vector2=local(p,d)
	var r:float=Vector2(q.x,q.y*(2 if id==2 else 1)).length()/d.radius
	var foundation:float=1-smoothstep(.15,.9,r);var excavation:float=exp(-pow((r-.94)/.24,2))*settings.excavation_strength
	var path:float=0;var satellite:float=0
	for site:Vector2 in satellites(d):
		var distance:Vector2=segment(p,d.position,site);path=maxf(path,1-smoothstep(12,36,distance.x));satellite=maxf(satellite,1-smoothstep(28,110,p.distance_to(site)))
	var h:float=65+macro(p)*[35,20,30,18,45,230][id]+noise(p)*2
	h+=foundation*(40 if id==1 or id==3 else 18)+satellite*12+excavation*10-path*2
	if id==1:h-=exp(-pow(r/.2,2))*28
	if id==4:h-=foundation*8
	var water:float=0
	if id==4 and d.chance<settings.water_frequency:water=48*(1-smoothstep(.35,.8,r));h=lerpf(h,40,foundation)
	return PackedFloat64Array([h,water,.2+d.age*.3,0,clampf(foundation+satellite*.7+path*.6,0,1)])
