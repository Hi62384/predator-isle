extends RefCounted
## Six bounded opaque templates:four weathered hexagonal column variants,
## one volcanic block and one obsidian wedge. No transparent crystal prisms.
const Shared=preload("res://scripts/biome_extension_structures.gd")
var templates:Dictionary={}
func quad(b,a:Vector3,c:Vector3,d:Vector3,e:Vector3,center:Vector3)->void:
	if (d-a).cross(c-a).dot((a+c+d+e)*.25-center)<0:b.quad(a,e,d,c,Color.WHITE)
	else:b.quad(a,c,d,e,Color.WHITE)
func prototype(kind:int,variant:int=0)->PackedVector3Array:
	variant=posmod(variant,4) if kind==0 else 0
	var cache_key:int=kind*4+variant
	if templates.has(cache_key):return templates[cache_key]
	var b=Shared.new();b._skip_degenerate=true;var center:=Vector3(0,.5,0)
	if kind==0:
		var previous:=PackedVector3Array()
		var levels:Array[float]=[0,.14,.15,.165,.3,.31,.325,.47,.48,.495,.66,.67,.685,.83,.84,.855,1]
		for ring in range(levels.size()):
			var points:=PackedVector3Array();var y:float=levels[ring];var joint:bool=ring>0 and ring<levels.size()-1 and ring%3==2;var radius:float=lerpf(1,.89,y)*(0.97 if joint else 1.0)
			for side in range(6):
				var a:float=side*TAU/6;var r:float=radius*(1+.035*sin(a*2+variant*.73));var top:float=.97+.03*cos(a*2+variant*.7) if ring==levels.size()-1 else y;var bend:=Vector2(sin(y*3+variant),cos(y*3+variant))*.025*y;points.append(Vector3(cos(a)*r+bend.x,top,sin(a)*r+bend.y))
			for side in range(6):
				var next:int=(side+1)%6
				if ring>0:quad(b,previous[side],points[side],points[next],previous[next],center)
				if ring==0:b.triangle(Vector3.ZERO,points[next],points[side],Color.WHITE)
				if ring==levels.size()-1:b.triangle(Vector3.UP*.97,points[side],points[next],Color.WHITE)
			previous=points
	else:
		var base:Array[Vector3]=[Vector3(-1,0,-.45),Vector3(-.72,0,-.7),Vector3(.68,0,-.7),Vector3(1,0,-.39),Vector3(1,0,.37),Vector3(.65,0,.7),Vector3(-.69,0,.7),Vector3(-1,0,.4)];var tops:Array[Vector3]=[]
		for i in range(8):tops.append(base[i]*(.7+.07*sin(i*2.3))+Vector3(.08,(.87+.13*sin(i*1.7)) if kind==1 else ([.25,.4,.7,1.0,.8,.55,.3,.2][i]),.04))
		var top_center:=Vector3(.08,.86 if kind==1 else .53,.04)
		for i in range(8):
			var j:int=(i+1)%8;quad(b,base[i],tops[i],tops[j],base[j],center);b.triangle(Vector3.ZERO,base[j],base[i],Color.WHITE);b.triangle(top_center,tops[i],tops[j],Color.WHITE)
	templates[cache_key]=b.vertices;return b.vertices
