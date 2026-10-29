extends "res://scripts/biome_extension_structures.gd"
## Frozen original summit-cap implementation; additional argument is ignored.
func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color,_vent_depth:float=0,broad_dome:bool=false)->void:
	if broad_dome:
		# Isolate the original cap under the separately registered dome profile.
		# The branch below remains the frozen original primitive when false.
		super.mound(builder,anchor,width,height,archetype,phase,color,0,true);return
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
	var sums:Dictionary={}
	for i in range(first_vertex,vertices.size()):sums[vertices[i]]=sums.get(vertices[i],Vector3.ZERO)+normals[i]
	for i in range(first_vertex,vertices.size()):
		var smooth:Vector3=sums[vertices[i]].normalized()
		if smooth.dot(normals[i])>.15:normals[i]=smooth
