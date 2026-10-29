extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Quartz plains","Amethyst highlands","Selenite blade wastes","Smoky crystalline ridges","Fluorite block country","Mineral basins"]
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var d:Dictionary=nearby(p,1700*settings.feature_scale);var q:Vector2=local(p,d)
	var growth:float=(1-smoothstep(.4,1.6,q.length()/d.radius+noise(p)*.15))*settings.structure_density
	var ridge:float=pow(1-absf(macro(p*.7)),5)
	var h:float=65+macro(p)*[25,200,65,350,120,20][id]+noise(p)*[2,7,3,8,4,1][id]+ridge*[15,120,25,220,60,5][id]
	var vein:float=1-smoothstep(22,80,absf(q.y+sin(q.x/700)*90));h+=vein*growth*18
	var water:float=0
	if id==5:
		var basin:float=1-smoothstep(.4,1.2,q.length()/d.radius);h=lerpf(h,24+noise(p),basin)
		if d.chance<settings.water_frequency:water=32*(1-smoothstep(.8,1.4,q.length()/d.radius))
	return PackedFloat64Array([h,water,.2,0,growth])
