extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Shield volcano","Stratovolcano","Collapse caldera","Cinder fields","Hardened lava plains","Ancient rift highlands"]
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var span:float=(7200 if id<3 else 2600)*settings.feature_scale;var d:Dictionary=nearby(p,span);var q:Vector2=local(p,d)
	var radius:float=d.radius*(1+noise(p*.25)*.12);var r:float=Vector2(q.x,q.y*.88).length()/radius
	var angle:float=q.angle();var age:float=d.age*settings.weathering
	var height:float=settings.volcano_height*(.65+d.age*.5);var edifice:float=0;var crater:float=0
	match id:
		0:
			edifice=height*pow(maxf(0,1-r*.45),2)*.65
			crater=(1-smoothstep(.12,.3,r))*height*.18
		1:
			edifice=height*pow(maxf(0,1-r*.7),1.25)
			crater=(1-smoothstep(.1,.26,r))*height*.32
		2:
			edifice=height*.65*(1-smoothstep(.9,1.5,r))
			crater=height*.5*(1-smoothstep(.61,.79,r))
		3:
			edifice=height*.18*pow(maxf(0,1-r),1.1)
			crater=height*.075*(1-smoothstep(.12,.28,r))
		4:edifice=22+macro(p)*38
		5:edifice=height*.25*pow(1-absf(macro(p)),3)
	var drainage:float=pow(.5+.5*sin(angle*11+noise(p*.18)*2),5)*smoothstep(.28,.7,r)*(1-smoothstep(1,1.6,r))*age
	var flow:float=(1-smoothstep(.09,.2,absf(sin(angle*3+sin(r*3)*.25+d.angle))))*smoothstep(.2,.4,r)*(1-smoothstep(1.2,1.8,r))*settings.lava_coverage
	var rough:float=lerpf(noise(p)*2,absf(noise(p*1.8))*15,float(d.kind%2))
	var h:float=45+macro(p)*35+edifice-crater-drainage*height*.12+flow*(8+rough)
	if id<3 and d.chance<settings.active_frequency:h-=(1-smoothstep(.05,.24,r))*minf(height*.18,130)
	if id==5:h-=35*(1-smoothstep(40,130,absf(q.y+sin(q.x/700)*130)))
	var water:float=0
	if d.chance<settings.water_frequency and d.chance>=settings.active_frequency and id==2:water=(45+height*.23)*(1-smoothstep(.82,1.05,r))
	return PackedFloat64Array([h,water,clampf(age*.7,0,1),0,flow])
func active_lava_descriptor(p:Vector2)->Dictionary:
	var d:Dictionary=nearby(p,7200*settings.feature_scale)
	return {"source":d.id,"position":d.position,"eligible":d.chance<settings.active_frequency,"renderer_supported":true,"rendered":"Only when a closed dry crater passes the feature mesher's bed/rim test","kind":"retained crater lava, not freshwater"}
