extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Barren exclusion plains","Ancient blast scars","Vitrified event ground","Mineralized highlands","Fallout dust lobes","Dry mineral lakebeds"]
func source_field(p:Vector2)->Dictionary:
	var d:Dictionary=nearby(p,4400*settings.feature_scale);var q:Vector2=(p-d.position).rotated(-settings.fallout_wind.angle());var r:float=q.length()/d.radius
	var deposition:float=exp(-pow(q.x/(d.radius*2.2),2)-pow(q.y/(d.radius*.5),2))*smoothstep(-d.radius*.2,d.radius*.4,q.x)
	return {"id":d.id,"age":d.age,"radius":r,"kind":d.kind,"contamination":clampf((exp(-r*r)*.6+deposition*.4)*(1-d.age*settings.weathering*.65),0,1),"damage":(1-smoothstep(.9,1.35,r)) if d.chance<settings.catastrophe_frequency else 0,"deposition":deposition,"descriptor":d}
func drainage(p:Vector2)->Vector3:
	var host=_host.get_ref();var spacing:float=4000/maxf(host.settings.grass_river_frequency,.01);var lane:int=roundi(p.y/spacing)
	var root_x:float=roundf(p.x/2400)*2400;var root_z:float=host._grass_river_center(root_x,lane,spacing);var side:float=signf(p.y-root_z)
	var root:=Vector2(root_x,root_z);var distance:float=INF;var grade:float=0
	for branch in range(3):
		var tip:Vector2=root+Vector2((branch-1)*650,side*(1300+branch*280));var near:Vector2=segment(p,root,tip)
		if near.x<distance:distance=near.x;grade=near.y*80+6
	return Vector3(distance,grade,1-smoothstep(20,200,distance))
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var s:Dictionary=source_field(p);var d:Dictionary=s.descriptor;var q:Vector2=local(p,d)
	var r:float=s.radius*(1+.08*sin(q.angle()*3+d.angle));var event:float=s.damage
	var h:float=70+macro(p)*[30,60,25,230,25,12][id]+noise(p)*[1,4,2,8,1,.5][id]
	if id==1 or id==2:
		var bowl:float=1-smoothstep(.15,.95,r);var rim:float=smoothstep(.65,.92,r)*(1-smoothstep(.94,1.2,r))
		h+=event*settings.crater_depth*(-bowl+rim*.24)*(1-d.age*.25)
	if id==3:h+=pow(1-absf(macro(p*.6)),4)*180
	if id==4:h+=s.deposition*8
	if id==5:h=lerpf(h,26+noise(p)*.7,1-smoothstep(.45,1.4,r))
	var channel:Vector3=drainage(p)
	var weathered_cut:float=(1-smoothstep(16,160,channel.x))*settings.drainage_strength*(.25+d.age*.75)
	h=lerpf(h,minf(h,channel.y+pow(channel.x/160,1.4)*100),weathered_cut)
	# Local alluvium is tied to the same outlet-connected channel, while fallout
	# deposition remains a separate downwind field.
	h+=channel.z*(1-weathered_cut)*s.deposition*2
	var water:float=0
	if (id==1 or id==5) and d.chance<settings.water_frequency:
		water=(30 if id==5 else 70-settings.crater_depth*.65)*(1-smoothstep(.75,1.2,r))
	return PackedFloat64Array([h,water,.15+maxf(0,water-h)*.02,0,event if id<3 else s.deposition])
func describe(p:Vector2)->Dictionary:
	var v:Dictionary=super.describe(p);var source:Dictionary=source_field(p);v["contamination"]=source.contamination;v["physical_damage"]=source.damage;v["fallout_deposition"]=source.deposition;v["drainage_distance"]=drainage(p).x;return v
