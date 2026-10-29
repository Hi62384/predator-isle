extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Sandstone pillar forest","Granite peaks","Limestone tower karst","Weathered highlands","Mountain labyrinth","Open river valley"]
func tributary(p:Vector2)->Vector4:
	var host=_host.get_ref();var spacing:float=4000/maxf(host.settings.grass_river_frequency,.01)
	var index:int=roundi(p.x/4096);var lane:int=roundi(p.y/spacing);var x:float=index*4096+sin(index*1.7+seed_value)*180
	var lateral:float=absf(p.x-x)
	if lateral>70:return Vector4.ZERO
	var outlet:float=host._grass_river_center(x,lane,spacing);var side:float=1 if random(index,lane,921)>.5 else -1
	var t:float=(p.y-outlet)*side/1000;var support:float=(1-smoothstep(14,38,lateral))*smoothstep(.025,.12,t)*(1-smoothstep(.94,1,t))
	return Vector4(4+8*t+34*smoothstep(.488,.512,t),support,t,x)
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var width:float=settings.pillar_width*settings.feature_scale
	var warp:Vector2=p+Vector2(macro(p+Vector2(39,887)),macro(p+Vector2(1771,13)))*width*1.7
	var a:float=absf(sin(warp.x/(width*1.5)+noise(p*.4)*.5));var b:float=absf(sin((warp.y+warp.x*.23)/(width*1.2)))
	var joint:float=minf(a,b);var column:float=smoothstep(.10,.24,joint)
	var uplift:float=settings.pillar_height*(.5+macro(p*.8)*.8+noise(p*.25)*.3)
	var h:float=55+macro(p)*35;var peak:float=0
	match id:
		0:peak=column*uplift*(.88+noise(p*.35)*.08)+column*noise(p*2.2)*12
		1:peak=pow(1-absf(macro(p*1.5)),4)*uplift*(.6+absf(noise(p*.5)))
		2:peak=pow(smoothstep(.17,.53,a*b),.45)*uplift*.7
		3:peak=(.3+macro(p*.6))*.6*uplift+noise(p*.4)*50
		4:peak=smoothstep(.08,.23,joint)*uplift*.8
		5:peak=column*uplift*smoothstep(.3,.8,absf(macro(p*.7)))
	var host=_host.get_ref();var spacing:float=4000/maxf(host.settings.grass_river_frequency,.01);var lane:int=roundi(p.y/spacing)
	var distance:float=absf(p.y-host._grass_river_center(p.x,lane,spacing))
	var valley:float=1-smoothstep(80,520 if id==2 or id==5 else 180,distance)
	h+=peak;h=lerpf(h,10+noise(p)*1.4,valley);h=lerpf(h,-3,1-smoothstep(25,50,distance))
	# Joint-ledges are physical meso relief, not just painted bands. Valley beds
	# stay clear; controls depend only on world coordinates, never leaf LOD.
	h+=(1-valley)*column*(sin(p.y/67+sin(p.x/370)*.6)*4+noise(p*2.7)*7)
	var stream:Vector4=tributary(p)
	var water:float=4*(1-smoothstep(90,170,distance))
	if stream.y>0:
		h=lerpf(h,minf(h,stream.x-3),stream.y);water=maxf(water,stream.x*stream.y)
	return PackedFloat64Array([h,water,clampf(.4+maxf(valley,stream.y)*.6,0,1),0,column])
