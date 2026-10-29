extends RefCounted
## Bounded numeric prototypes reuse the EXISTING surface crystal emitter.
## Cave attachment/orientation is separate;no surface crystal behavior changes.
const Shared=preload("res://scripts/biome_extension_structures.gd")
class RootPlane extends RefCounted:
	func _get_height(_x:float,_z:float)->float:return 8.0
var templates:Dictionary={}
func quad(builder,a:Vector3,b:Vector3,c:Vector3,d:Vector3,center:Vector3)->void:
	if (c-a).cross(b-a).dot((a+b+c+d)*.25-center)<0:builder.quad(a,d,c,b,Color.WHITE)
	else:builder.quad(a,b,c,d,Color.WHITE)
func prototype(habit:int,broken:bool)->Array:
	var key:int=habit*2+int(broken)
	if templates.has(key):return templates[key]
	var b=Shared.new();b._skip_degenerate=true;b.crystal_bulk_material=true
	if habit==5:
		# Calcite's skewed rhombohedral block is not a quartz point or ice cone.
		var bottom:Array=[Vector3(-1,0,-.75),Vector3(1,0,-.75),Vector3(1.5,0,.75),Vector3(-.5,0,.75)];var shift:=Vector3(.45,1,.22);var center:Vector3=(bottom[0]+bottom[2]+shift)*.5
		for i in range(4):var j:int=(i+1)%4;quad(b,bottom[i],bottom[j],bottom[j]+shift,bottom[i]+shift,center)
		quad(b,bottom[0],bottom[1],bottom[2],bottom[3],center);quad(b,bottom[0]+shift,bottom[1]+shift,bottom[2]+shift,bottom[3]+shift,center)
		for i in range(b.vertices.size()):b.uvs[i]=Vector2(5+clampf(b.vertices[i].y,0,1)*.25,1.5)
	else:
		b.prism(RootPlane.new(),Vector3.ZERO,1,1,habit,0,Vector2.ZERO,broken,Color.WHITE)
		var sides:int=6 if habit<2 or habit==3 else 4
		for i in range(sides):
			var a:float=i*TAU/sides;var c:float=(i+1)*TAU/sides;b.triangle(Vector3.ZERO,Vector3(cos(c),0,sin(c)*(.14 if habit==2 else 1)),Vector3(cos(a),0,sin(a)*(.14 if habit==2 else 1)),Color.WHITE)
		for i in range(b.vertices.size()):b.uvs[i]=Vector2(habit+clampf(b.vertices[i].y,0,1)*.25,2*(.14 if habit==2 else 1))
	var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=b.vertices;result[Mesh.ARRAY_NORMAL]=b.normals;result[Mesh.ARRAY_TEX_UV]=b.uvs;templates[key]=result;return result
static func tint(family:int,age:float)->Color:
	var colors:Array[Color]=[Color(.79,.84,.83),Color(.39,.24,.53),Color(.86,.86,.77),Color(.37,.31,.26),Color(.48,.65,.58),Color(.82,.71,.52)]
	return colors[clampi(family,0,5)].lerp(Color(.38,.35,.30),age*.18)
