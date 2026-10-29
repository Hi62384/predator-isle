extends "res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd"
## Private longitudinal blade morphology; false reproduces the original growth ribs.
var longitudinal_ribs:bool=true
## Worker-only, closed organic buttress blades at actual network junctions.
## This is landscape geometry, not a creature, prop or new cave generator.
func emit(g,builder,point:Vector2,directions:Array[Vector2],width:float,height:float,phase:float)->void:
	var first_vertex:int=g.vertices.size()
	var ground:float=builder._get_height(point.x,point.y)
	var tint:=Color(.34,.28,.26)
	for blade in range(directions.size()):
		var axis:Vector2=directions[blade].normalized();var side:=Vector2(-axis.y,axis.x)
		var scale:float=1.0 if blade==0 else .68
		var rings:Array[PackedVector3Array]=[]
		var sides:int=20;var rows:int=24
		for row in range(rows+1):
			var t:float=float(row)/rows;var ring:=PackedVector3Array()
			# A narrow blade and bowed spine, not a round mud-tower profile.
			var length:float=width*scale*(.035+.965*pow(1-t,1.1))
			var thickness:float=width*scale*(.025+.16*pow(1-t,.65))
			var center:Vector2=point+axis*width*scale*.6*sin(t*PI*.65)+side*width*.07*sin(t*PI+phase)*t
			for i in range(sides):
				var angle:float=float(i)*TAU/sides
				# Low-amplitude physical growth ribs, fading into the buried root.
				var rib:float=1+(.115*sin(angle*5+phase+t*.7)+.035*sin(angle*11-phase-t*1.3))*smoothstep(0,.15,t) if longitudinal_ribs else 1+.09*sin(t*TAU*6+phase+sin(angle)*.8)*smoothstep(0,.15,t)
				var q:Vector2=center+axis*cos(angle)*length*rib+side*sin(angle)*thickness*rib
				var v:=Vector3(q.x,ground+height*scale*t,q.y)
				if row==0:
					v.y=g.footing_height(builder,q)
					g._footing_vertices[v-g.origin]=0.0
				builder._extras[7].sample(q.x,q.y)
				g._conduit_uvs[v-g.origin]=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
				ring.append(v)
			rings.append(ring)
		for row in range(rows):
			for i in range(sides):
				var j:int=(i+1)%sides;g.quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],tint)
		# Close both ends. Buried bottom is included in collision too; there is
		# no apparent mouth or unsupported claim of a traversable opening.
		var bottom:=Vector3.ZERO;var top:=Vector3.ZERO
		for i in range(sides):bottom+=rings[0][i]/sides;top+=rings[-1][i]/sides
		builder._extras[7].sample(point.x,point.y)
		var controls:=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
		g._conduit_uvs[bottom-g.origin]=controls;g._conduit_uvs[top-g.origin]=controls
		for i in range(sides):
			var j:int=(i+1)%sides;g.triangle(rings[0][j],rings[0][i],bottom,tint);g.triangle(rings[-1][i],rings[-1][j],top,tint)
	root_strut(g,builder,point,directions[0].normalized(),width,height,phase,ground,tint)
	# Shared geometric normals retain the outward hemisphere at sharp folds.
	var sums:Dictionary={}
	for i in range(first_vertex,g.vertices.size()):sums[g.vertices[i]]=sums.get(g.vertices[i],Vector3.ZERO)+g.normals[i]
	for i in range(first_vertex,g.vertices.size()):
		var smooth:Vector3=sums[g.vertices[i]].normalized()
		if smooth.dot(g.normals[i])>.15:g.normals[i]=smooth
	g._footing_vertices.clear();g._conduit_uvs.clear()
