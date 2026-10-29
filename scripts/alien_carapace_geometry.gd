extends RefCounted
## Worker-only overlapping dorsal plates rooted at admitted hive-network nodes.
func emit(g,builder,point:Vector2,axis:Vector2,width:float,height:float,phase:float,habit:int=2)->void:
	var first_vertex:int=g.vertices.size();var side:=Vector2(-axis.y,axis.x)
	var tint:=Color(.74,.72,.66) if habit==5 else Color(.25,.26,.27)
	var controls:=Vector2(habit,1.0)
	var sides:int=40;var rows:int=24
	for plate in range(3):
		var scale:float=[.8,1.0,.88][plate]
		var center:Vector2=point+axis*(plate-1)*width*.55+side*width*.07*sin(phase+plate*2.1)
		var base:float=builder._get_height(center.x,center.y)
		var length:float=width*.95*scale;var breadth:float=width*.32*scale;var rise:float=height*[.72,1.0,.83][plate]
		var rings:Array[PackedVector3Array]=[]
		for row in range(rows+1):
			var t:float=float(row)/rows;var core_radius:float=maxf(.015,1-t)
			var radius:float=core_radius+.045*sin(clampf(t/.4,0,1)*PI);var ring:=PackedVector3Array()
			for i in range(sides):
				var angle:float=float(i)*TAU/sides
				var edge:float=1+.035*sin(angle*5+phase+plate*.7)+.02*cos(angle*9-phase)
				var along:float=signf(cos(angle))*pow(absf(cos(angle)),.8)*length*radius*edge
				var across:float=sin(angle)*breadth*radius*edge
				var q:Vector2=center+axis*along+side*across
				var keel:float=maxf(0,1-absf(across)/maxf(breadth*.4,1))*rise*.3*(1-core_radius*core_radius)
				var arch:float=sqrt(maxf(0,1-core_radius*core_radius))
				var growth:float=rise*.15*pow(.5+.5*cos(along/maxf(length,1)*PI*5+sin(across/maxf(breadth,1)*2+phase)),4)*(1-core_radius*core_radius)
				var deck:float=rise*(.72+.28*arch)+keel+growth-rise*.25*(along/maxf(length,1))+rise*.08*sin(angle*3+phase)*core_radius*core_radius
				var y:float=base+deck*smoothstep(0,.38,t)
				var v:=Vector3(q.x,y,q.y)
				if row==0:v.y=g.footing_height(builder,q);g._footing_vertices[v-g.origin]=0.0
				g._conduit_uvs[v-g.origin]=controls;ring.append(v)
			rings.append(ring)
		for row in range(rows):
			for i in range(sides):
				var j:int=(i+1)%sides;g.quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],tint)
		var bottom:=Vector3.ZERO;var top:=Vector3.ZERO
		for i in range(sides):bottom+=rings[0][i]/sides;top+=rings[-1][i]/sides
		g._conduit_uvs[bottom-g.origin]=controls;g._conduit_uvs[top-g.origin]=controls
		for i in range(sides):
			var j:int=(i+1)%sides;g.triangle(rings[0][j],rings[0][i],bottom,tint);g.triangle(rings[-1][i],rings[-1][j],top,tint)
	var sums:Dictionary={}
	for i in range(first_vertex,g.vertices.size()):sums[g.vertices[i]]=sums.get(g.vertices[i],Vector3.ZERO)+g.normals[i]
	for i in range(first_vertex,g.vertices.size()):
		var normal:Vector3=sums[g.vertices[i]].normalized()
		if normal.dot(g.normals[i])>.7:g.normals[i]=normal
	g._footing_vertices.clear();g._conduit_uvs.clear()
