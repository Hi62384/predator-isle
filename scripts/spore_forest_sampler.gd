extends "res://scripts/biome_extension_sampler.gd"
const NAMES=["Mycelium lowlands","Colony mounds","Pale crustlands","Decomposition basins","Rocky fungal highlands","Dry spore residue"]
var _ecology_point:=Vector2.INF
var _ecology:Dictionary={}
func configure(config:Resource,seed_id:int,host:RefCounted,family_id:int)->void:
	_ecology_point=Vector2.INF;_ecology.clear();super.configure(config,seed_id,host,family_id)
func ecology(p:Vector2)->Dictionary:
	if p==_ecology_point:return _ecology
	var span:float=1800*settings.feature_scale;var cell:=Vector2i(floori(p.x/span),floori(p.y/span))
	var uncovered:float=1;var mound:float=0;var luminous:float=0;var weighted_age:float=0;var sum:float=0
	for dz in range(-1,2):
		for dx in range(-1,2):
			var owner:Vector2i=cell+Vector2i(dx,dz);var d:Dictionary=descriptor(owner,span);var q:Vector2=local(p,d)/d.radius
			var elongation:float=.55+d.age*.45
			var edge:float=Vector2(q.x,q.y*elongation).length()+noise(p)*.2+.09*sin(q.angle()*3+d.angle)
			var cover:float=1-smoothstep(.35+d.age*.16,1.1+d.age*.3,edge)
			# Stable half-open edge ownership; overlapping colonies unite rather
			# than switching abruptly at nearest-centre Voronoi boundaries.
			var link:float=0
			for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
				if random(owner.x,owner.y,801+direction.x*7)>.48:continue
				var other:Dictionary=descriptor(owner+direction,span);var axis:Vector2=other.position-d.position
				var bend:Vector2=(d.position+other.position)*.5+Vector2(-axis.y,axis.x)*((d.age-.5)*.3)
				var distance:float=minf(segment(p,d.position,bend).x,segment(p,bend,other.position).x)
				var width:float=lerpf(40,100,d.age)*settings.feature_scale
				link=maxf(link,(1-smoothstep(width*.3,width*2.2,distance))*.72)
			cover=maxf(cover,link);uncovered*=1-cover;weighted_age+=cover*d.age;sum+=cover
			mound=maxf(mound,pow(maxf(cover,0),1.7)*(.35+d.age*.75))
			if d.chance<settings.luminous_frequency:luminous=maxf(luminous,cover*(.75+d.age*.25))
	_ecology_point=p;_ecology={"coverage":(1-uncovered)*settings.mycelium,"age":weighted_age/maxf(sum,.001),"mound":mound,"luminous":luminous*settings.mycelium}
	return _ecology
func evaluate(p:Vector2,id:int)->PackedFloat64Array:
	var d:Dictionary=nearby(p,1800*settings.feature_scale);var q:Vector2=local(p,d)
	var distance:float=Vector2(q.x,q.y*.65).length()/d.radius+noise(p)*.22
	var field:Dictionary=ecology(p);var colony:float=field.coverage
	var h:float=40+macro(p)*[18,45,35,18,240,16][id]+noise(p)*[1,2,1,1,7,1][id]
	if id==1:h+=field.mound*settings.mound_height
	if id==2:h+=colony*6
	if id==3:h-=colony*22
	if id==4:h+=pow(1-absf(macro(p*.7)),3)*120
	var wet:float=clampf(.35+colony*.4+(.2 if id==3 else 0)-(.3 if id==5 else 0),0,1)
	var water:float=0
	if id==3 and d.chance<settings.water_frequency:water=27*(1-smoothstep(.65,1.2,distance));h=lerpf(h,19+noise(p),1-smoothstep(.5,.8,distance))
	# Compact continuous ecology signal: ordinary fungal coverage occupies
	# [0,.5]; only selected luminous colonies can exceed .5. Shader coverage
	# saturates at one for mature luminous centres instead of unpacking a flag.
	return PackedFloat64Array([h,water,wet,0,.5*colony+.5*field.luminous])
func describe(p:Vector2)->Dictionary:
	var v:Dictionary=super.describe(p);var d:Dictionary=nearby(p,1800*settings.feature_scale)
	var field:Dictionary=ecology(p)
	v.merge({"colony_id":d.id,"colony_age":field.age,"colony_coverage":field.coverage,"luminous_potential":field.luminous,"luminous":field.luminous>.5,"spore_dose_calibrated":false});return v
