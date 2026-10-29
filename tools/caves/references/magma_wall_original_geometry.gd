extends RefCounted
## Three reusable opaque volcanic habits. Basalt has flat jointed hexagonal
## caps; obsidian uses a fractured wedge, never a transparent crystal prism.
const Shared=preload("res://scripts/biome_extension_structures.gd")
var templates:Dictionary={}
func quad(b,a:Vector3,c:Vector3,d:Vector3,e:Vector3,center:Vector3)->void:
	if (d-a).cross(c-a).dot((a+c+d+e)*.25-center)<0:b.quad(a,e,d,c,Color.WHITE)
	else:b.quad(a,c,d,e,Color.WHITE)
func prototype(kind:int)->PackedVector3Array:
	if templates.has(kind):return templates[kind]
	var b=Shared.new();b._skip_degenerate=true;var center:=Vector3(0,.5,0)
	if kind==0:
		var previous:=PackedVector3Array()
		for ring in range(5):
			var points:=PackedVector3Array();var y:float=ring*.25;var radius:float=[1.0,.97,1.01,.94,.89][ring]
			for side in range(6):var a:float=side*TAU/6;points.append(Vector3(cos(a)*radius,y,sin(a)*radius))
			for side in range(6):
				var next:int=(side+1)%6
				if ring>0:quad(b,previous[side],points[side],points[next],previous[next],center)
				if ring==0:b.triangle(Vector3.ZERO,points[next],points[side],Color.WHITE)
				if ring==4:b.triangle(Vector3.UP,points[side],points[next],Color.WHITE)
			previous=points
	else:
		var base:Array[Vector3]=[Vector3(-1,0,-.7),Vector3(1,0,-.7),Vector3(1,0,.7),Vector3(-1,0,.7)];var tops:Array[Vector3]=[]
		for i in range(4):tops.append(base[i]*.8+Vector3(.12,1.0 if kind==1 else ([.3,1.0,.7,.2][i]),.08))
		for i in range(4):var j:int=(i+1)%4;quad(b,base[i],tops[i],tops[j],base[j],center)
		quad(b,base[0],base[1],base[2],base[3],center);quad(b,tops[0],tops[3],tops[2],tops[1],center)
	templates[kind]=b.vertices;return b.vertices
