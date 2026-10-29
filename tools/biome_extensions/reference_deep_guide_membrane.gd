extends RefCounted
## Worker-owned thick membrane anchored inside an admitted blade and root strut.
## Closed volume and buried far root; an exterior landscape structure, not a cave.
func emit(g,builder,point:Vector2,axis:Vector2,width:float,height:float,phase:float)->void:
	var first:int=g.vertices.size();axis=axis.normalized();var side:=Vector2(-axis.y,axis.x);var ground:float=builder._get_height(point.x,point.y)
	var shoulder:float=.65
	var a2:Vector2=point+axis*width*.6*sin(shoulder*PI*.65)+side*width*.07*sin(shoulder*PI+phase)*shoulder
	var b2:Vector2=point+axis*width*3.6
	var a:=Vector3(a2.x,ground+height*shoulder,a2.y);var b:=Vector3(b2.x,g.footing_height(builder,b2),b2.y)
	var control:=Vector3(point.x+axis.x*width*3,ground+height*1.02,point.y+axis.y*width*3)
	var segments:int=32;var rows:int=12;var faces:Array=[]
	for face:int in [-1,1]:
		var vertices:=PackedVector3Array()
		for column in range(segments+1):
			var u:float=float(column)/segments;var center:Vector3=a*(1-u)*(1-u)+control*2*(1-u)*u+b*u*u
			var floor_height:float=builder._get_height(center.x,center.z)
			# Existing maximum-age conduits rise up to 7.8m above flat ground.
			# The old canonical+8 guard could leave only 0.2m of headroom.
			# Reserve four additional metres without detaching the upper/root edges.
			var bottom:float=minf(center.y-width*.025,maxf(lerpf(a.y-height*.3,b.y-width*.1,u)+height*.16*sin(u*PI),floor_height+12))
			for row in range(rows+1):
				var v:float=float(row)/rows;var envelope:float=sin(u*PI)*sin(v*PI)
				var billow:float=width*.11*envelope*(.7+.3*sin(phase+u*7+v*4));var fold:float=0
				for rib in range(3):
					var offset:float=[.28,.55,.81][rib]+(v-.5)*(v-.5)*[.08,-.11,.06][rib]
					var q:float=absf(u-offset)/[.1,.13,.07][rib]
					fold+=pow(maxf(0,1-q*q),3)*[.045,-.035,.055][rib]*width*sin(v*PI)
				var thickness:float=width*.035*(.8+.2*sin(v*PI))
				var p:=Vector3(center.x+side.x*(billow+fold+face*thickness),lerpf(bottom,center.y,v),center.z+side.y*(billow+fold+face*thickness))
				if column==segments:
					p.y=g.footing_height(builder,Vector2(p.x,p.z))-width*.1*(1-v);g._footing_vertices[p-g.origin]=0.0
				builder._extras[7].sample(p.x,p.z)
				# A real membrane tissue role, not nerve/carpet albedo across a wall.
				g._conduit_uvs[p-g.origin]=Vector2(3,builder._extras[7].state[4]);vertices.append(p)
		faces.append(vertices)
	var negative:PackedVector3Array=faces[0];var positive:PackedVector3Array=faces[1];var stride:int=rows+1;var tint:=Color(.34,.28,.26)
	for column in range(segments):
		for row in range(rows):
			var i:int=column*stride+row;var j:int=i+stride
			g.quad(negative[i],negative[j],negative[j+1],negative[i+1],tint)
			g.quad(positive[i],positive[i+1],positive[j+1],positive[j],tint)
		var lower:int=column*stride;var next:int=lower+stride;var upper:int=lower+rows;var next_upper:int=next+rows
		g.quad(positive[lower],positive[next],negative[next],negative[lower],tint)
		g.quad(positive[upper],negative[upper],negative[next_upper],positive[next_upper],tint)
	for row in range(rows):
		g.quad(positive[row],negative[row],negative[row+1],positive[row+1],tint)
		var i:int=segments*stride+row
		g.quad(positive[i],positive[i+1],negative[i+1],negative[i],tint)
	var sums:Dictionary={}
	for i in range(first,g.vertices.size()):sums[g.vertices[i]]=sums.get(g.vertices[i],Vector3.ZERO)+g.normals[i]
	for i in range(first,g.vertices.size()):
		var smooth:Vector3=sums[g.vertices[i]].normalized()
		if smooth.dot(g.normals[i])>.3:g.normals[i]=smooth
	g._footing_vertices.clear();g._conduit_uvs.clear()
