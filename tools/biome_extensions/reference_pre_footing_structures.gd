extends RefCounted
## Worker-side combined geometry. Each root is owned by exactly one half-open
## quadtree leaf; the complete-cut transaction swaps terrain AND structures.
## Root identity, geometry and anchors never depend on leaf size or load order.
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var uvs:=PackedVector2Array()
var origin:=Vector3.ZERO
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	var normal:Vector3=(c-a).cross(b-a).normalized() # Godot clockwise front faces
	for p:Vector3 in [a,b,c]:vertices.append(p-origin);normals.append(normal);colors.append(color);uvs.append(Vector2(p.x+p.z,p.y)*.15)
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color)->void:
	triangle(a,b,c,color);triangle(a,c,d,color)
func prism(builder,anchor:Vector3,width:float,height:float,habit:int,angle:float,tilt:Vector2,broken:bool,color:Color)->void:
	var count:int=6 if habit<2 or habit==3 else 4
	var rings:Array=[]
	for level in range(3):
		var ring:=PackedVector3Array();var t:float=[0,.76,1][level]
		var radius:float=width*(1 if level<2 or broken or habit==4 else .04)
		for i in range(count):
			var a:float=angle+float(i)*TAU/count
			var p:=Vector3(cos(a)*radius,height*t,sin(a)*radius*(.14 if habit==2 else 1))
			p.x+=tilt.x*height*t;p.z+=tilt.y*height*t
			var v:Vector3=anchor+p
			if level==0:v.y=minf(v.y,builder._get_height(v.x,v.z)-8)
			ring.append(v)
		rings.append(ring)
	for level in range(2):
		for i in range(count):
			var j:int=(i+1)%count;quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],color)
	var top:Vector3=anchor+Vector3(tilt.x*height,height,tilt.y*height)
	for i in range(count):triangle(rings[2][i],rings[2][(i+1)%count],top,color)
func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color)->void:
	var first_vertex:int=vertices.size()
	var rings:Array=[];var sides:int=42
	for row in range(25):
		var t:float=float(row)/24;var ring:=PackedVector3Array()
		for i in range(sides):
			var a:float=float(i)*TAU/sides
			var flute:float=1+.18*sin(a*5+phase+t*.9)+.1*sin(a*3-phase-t*1.4)+.045*sin(a*13+t*18+phase)
			var radius:float=width*pow(maxf(.015,1-t),.65)*flute
			if archetype==3:radius=width*sqrt(maxf(.005,1-t*t))
			if archetype==0 or archetype==4:radius*=.84+.16*sin(t*14+a*3+phase)+.06*sin(a*19+t*35)
			if archetype==4:radius*=1-.15*smoothstep(.4,1,t)*(.5+.5*sin(a*7+phase))
			var p:=Vector3(cos(a)*radius,height*t,sin(a)*radius*(.22 if archetype==2 else 1))
			p.x+=width*.16*sin(t*2+phase)*t;p.z+=width*.12*t*t
			var v:Vector3=anchor+p
			if row==0:v.y=minf(v.y,builder._get_height(v.x,v.z)-8)
			ring.append(v)
		rings.append(ring)
	for row in range(24):
		for i in range(sides):
			var j:int=(i+1)%sides;quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],color)
	var top:Vector3=Vector3.ZERO
	for v:Vector3 in rings[24]:top+=v/float(sides)
	for i in range(sides):triangle(rings[24][i],rings[24][(i+1)%sides],top,color)
	# Earth is rounded and weathered, unlike the deliberately hard crystal facets.
	var sums:Dictionary={}
	for i in range(first_vertex,vertices.size()):sums[vertices[i]]=sums.get(vertices[i],Vector3.ZERO)+normals[i]
	for i in range(first_vertex,vertices.size()):
		var smooth:Vector3=sums[vertices[i]].normalized()
		if smooth.dot(normals[i])>.15:normals[i]=smooth
func conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var rings:Array=[]
	var segments:int=clampi(ceili(a.distance_to(b)/96),16,64)
	for row in range(segments+1):
		var t:float=float(row)/segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8
		var h:float=builder._get_height(p.x,p.y);var ring:=PackedVector3Array();var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase))
		var left:Vector2=p+side*radius;var right:Vector2=p-side*radius
		var left_h:float=builder._get_height(left.x,left.y);var right_h:float=builder._get_height(right.x,right.y)
		for i in range(9):
			var angle:float=float(i)*PI/8
			var ground:float=lerpf(h,left_h if cos(angle)>0 else right_h,absf(cos(angle)))
			var v:=Vector3(p.x+side.x*cos(angle)*radius,ground-2+sin(angle)*radius*.35,p.y+side.y*cos(angle)*radius)
			# Deep buried margins close the underside against intervening valleys;
			# these are solid terrain conduits, never implied open cave mouths.
			if i==0 or i==8:v.y=ground-3
			ring.append(v)
		rings.append(ring)
	for row in range(segments):
		for i in range(8):quad(rings[row][i],rings[row][i+1],rings[row+1][i+1],rings[row+1][i],color)
	var cap_a:=Vector3(a.x,builder._get_height(a.x,a.y)-width*4,a.y)
	var cap_b:=Vector3(b.x,builder._get_height(b.x,b.y)-width*4,b.y)
	for i in range(8):
		triangle(rings[0][i+1],rings[0][i],cap_a,color)
		triangle(rings[segments][i],rings[segments][i+1],cap_b,color)
func build(builder,coordinate:Vector2i)->Array:
	var output:Array=[];output.resize(3);origin=Vector3(coordinate.x*builder.chunk_size,0,coordinate.y*builder.chunk_size)
	var bounds:=Rect2(Vector2(origin.x,origin.z),Vector2.ONE*builder.chunk_size)
	for family_id in [5,6,7]:
		vertices=PackedVector3Array();normals=PackedVector3Array();colors=PackedColorArray();uvs=PackedVector2Array()
		if builder._extras[family_id]==null:continue
		var sampler=builder._extras[family_id];var span:float=(4096 if family_id==7 else (1700 if family_id==5 else 2100))*sampler.settings.feature_scale
		var start:=Vector2i(floori(bounds.position.x/span)-1,floori(bounds.position.y/span)-1);var end:=Vector2i(ceili(bounds.end.x/span),ceili(bounds.end.y/span))
		for z in range(start.y,end.y+1):
			for x in range(start.x,end.x+1):
				var cell:=Vector2i(x,z);var d:Dictionary=sampler.descriptor(cell,span);var p:Vector2=sampler.hive_node(cell) if family_id==7 else d.position
				if not bounds.has_point(p):continue
				builder._biome_weights(p.x,p.y)
				var weight:float=builder._extra_weights[family_id]
				if family_id==7:weight=maxf(weight,sampler.network(p).influence*sampler.settings.overlay_strength)
				if weight<.55 or builder._island_mask(p.x,p.y)<.03 or d.chance>sampler.settings.structure_density:continue
				var height:float=builder._get_height(p.x,p.y);var water:float=builder.get_water_surface_height(p.x,p.y)
				if height<water+2:continue
				var anchor:=Vector3(p.x,height-8,p.y);var type:int=clampi(roundi(sampler.region(p)),0,5)
				if family_id==5:
					var palette:Array=[Color(.59,.61,.58),Color(.41,.27,.49),Color(.76,.77,.68),Color(.25,.23,.22),Color(.23,.46,.37),Color(.63,.56,.43)]
					for i in range(5):
						var a:float=d.angle+i*2.4;var scale:float=1 if i==0 else .22+sampler.random(x,z,i+70)*.4
						var center:Vector3=anchor+Vector3(cos(a),0,sin(a))*d.radius*.15*minf(i,1)
						center.y=minf(anchor.y,builder._get_height(center.x,center.z)-8)
						var size:float=sampler.settings.crystal_height*(.4+d.age*1.4)*scale
						prism(builder,center,size*(.14 if type!=4 else .4),size,type,a,Vector2(cos(a),sin(a))*(.05+.18*sampler.random(x,z,i+90)),sampler.random(x,z,i+80)<sampler.settings.broken_fraction,palette[type])
				elif family_id==6:
					if type==1:continue # broad ant earthworks are canonical heightfield geometry
					var color:Color=Color(.44,.27,.14).lerp(Color(.55,.48,.36),float(type)/5)
					var scale:float=sampler.settings.nest_height*(.45+d.age)*(1-.35*float(type==4))
					mound(builder,anchor,scale*.4,scale,type,d.angle,color)
					if type==0 or type==4 or type==5:
						for i in range(5):
							var a:float=d.angle+i*1.31;var base:Vector3=anchor+Vector3(cos(a),0,sin(a))*scale*.23
							mound(builder,base,scale*.19,scale*(.4+sampler.random(x,z,110+i)*.5),0,a,color)
				else:
					var color:=Color(.34,.28,.26);var a:Vector2=sampler.hive_node(cell)
					for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
						var b:Vector2=sampler.hive_node(cell+direction);var mid:Vector2=(a+b)*.5+Vector2(-(b-a).y,(b-a).x)*(.08*sin(float(x+z)*1.71))
						conduit(builder,a,mid,12+d.age*16,d.angle,color);conduit(builder,mid,b,12+d.age*16,d.angle,color)
						var tip:Vector2=mid+Vector2(-(b-a).y,(b-a).x)*.23;conduit(builder,mid,tip,8,d.angle,color)
		if not vertices.is_empty():
			var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;output[family_id-5]=arrays
	return output
