extends "res://scripts/biome_extension_structures.gd"
## Private exact reuse of already evaluated conduit surface/control samples.
func controls_after_height(builder,p:Vector2)->Vector2:
	# A full-payload height sample already publishes this field's state. A
	# fully replaced coast or absent Alien owner must retain the old sample.
	if builder._last_extras.size()!=8 or builder._extra_weights[7]<=0 or builder._last_extras[7].x<=0:
		builder._extras[7].sample(p.x,p.y)
	return Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
func footing_height(builder,p:Vector2,canonical:float=INF)->float:
	var lowest:float=canonical if is_finite(canonical) else builder._get_height(p.x,p.y)
	for index in range(_support_steps.size()):
		var step:float=_support_steps[index];var gx:float=p.x/step;var gz:float=p.y/step
		var x:int=floori(gx);var z:int=floori(gz);var fx:float=gx-x;var fz:float=gz-z
		var a:float=_grid_height(builder,x,z,index,step);var b:float=_grid_height(builder,x+1,z,index,step)
		var c:float=_grid_height(builder,x,z+1,index,step);var d:float=_grid_height(builder,x+1,z+1,index,step)
		var chord:float=a+(b-a)*fx+(c-a)*fz if fx+fz<=1 else d+(c-d)*(1-fx)+(b-d)*(1-fz)
		lowest=minf(lowest,chord)
	# A buried visual margin, not a new walking surface or a lowered terrain field.
	return lowest-32
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=conduit_aprons
	var first_vertex:int=vertices.size()
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var rings:Array=[]
	var segments:int=clampi(ceili(a.distance_to(b)/96),16,64)
	for row in range(segments+1):
		var t:float=float(row)/segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8
		var h:float=builder._get_height(p.x,p.y);var ring:=PackedVector3Array();var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase))
		var row_controls:=Vector2.ZERO
		if conduit_aprons:
			row_controls=controls_after_height(builder,p)
		var left:Vector2=p+side*radius;var right:Vector2=p-side*radius
		var left_h:float=builder._get_height(left.x,left.y);var right_h:float=builder._get_height(right.x,right.y)
		for i in range(9):
			var angle:float=float(i)*PI/8
			var ground:float=lerpf(h,left_h if cos(angle)>0 else right_h,absf(cos(angle)))
			# A half ellipse has a vertical tangent at its buried margin. Its
			# first exposed face formed a 67-degree knee-high wall on flat ground.
			# Squared sine keeps the exact crest and horizontal support but bounds the added
			# cross-slope by .7 (before the underlying terrain's own gradient).
			var rise:float=sin(angle)
			if conduit_aprons and conduit_shoulders:rise*=rise
			var v:=Vector3(p.x+side.x*cos(angle)*radius,ground-2+rise*radius*.35,p.y+side.y*cos(angle)*radius)
			# Deep buried margins close the underside against intervening valleys;
			# these are solid terrain conduits, never implied open cave mouths.
			if i==0 or i==8:v.y=ground-(2 if conduit_aprons and conduit_shoulders else 3)
			ring.append(v)
			if conduit_aprons:_conduit_uvs[v-origin]=row_controls
		if conduit_aprons:
			var reach:float=128+radius*4;var factor:float=1
			for site:Dictionary in _protected_sites:
				# The finite cavity includes a spiral and a 256m return gallery.
				# Keep every NEW apron outside that entire reserved approach.
				var clearance:float=p.distance_to(site.position)-maxf(320,site.half*1.2)-64-radius-16
				factor=minf(factor,clampf(clearance/reach,0,1))
			var profile:=PackedVector3Array()
			for sign_value:float in [1.0,-1.0]:
				var outer:Vector2=p+side*sign_value*(radius+reach*factor)
				var outer_ground:float=builder._get_height(outer.x,outer.y)
				var outer_controls:Vector2=controls_after_height(builder,outer)
				var foot:float=footing_height(builder,outer,outer_ground) if factor>0 else outer_ground-3
				var extra_depth:float=maxf(0,outer_ground-3-foot)
				var apron:=PackedVector3Array()
				for station in range(3):
					var u:float=float(3-station)/3
					var q:Vector2=p+side*sign_value*(radius+reach*factor*u)
					var same_outer:bool=station==0 and q==outer
					var surface:float=outer_ground if same_outer else builder._get_height(q.x,q.y)
					var y:float=surface-3-extra_depth*smoothstep(.35,1,u)
					var v:=Vector3(q.x,y,q.y);apron.append(v)
					_footing_vertices[v-origin]=(0.0 if station==0 else .25) if factor>0 else .5
					_conduit_uvs[v-origin]=outer_controls if same_outer else controls_after_height(builder,q)
				if sign_value>0:
					profile.append_array(apron);profile.append_array(ring)
				else:
					apron.reverse();profile.append_array(apron)
			ring=profile
		rings.append(ring)
	for row in range(segments):
		for i in range(rings[row].size()-1):quad(rings[row][i],rings[row][i+1],rings[row+1][i+1],rings[row+1][i],color)
	var cap_a:=Vector3(a.x,builder._get_height(a.x,a.y)-width*4,a.y)
	var cap_b:=Vector3(b.x,builder._get_height(b.x,b.y)-width*4,b.y)
	if conduit_aprons:
		cap_a.y=minf(cap_a.y,minf(rings[0][0].y,rings[0][-1].y)-8)
		cap_b.y=minf(cap_b.y,minf(rings[segments][0].y,rings[segments][-1].y)-8)
		_conduit_uvs[cap_a-origin]=_conduit_uvs[rings[0][3]-origin]
		_conduit_uvs[cap_b-origin]=_conduit_uvs[rings[segments][3]-origin]
	for i in range(rings[0].size()-1):
		triangle(rings[0][i+1],rings[0][i],cap_a,color)
		triangle(rings[segments][i],rings[segments][i+1],cap_b,color)
	if conduit_aprons:
		# Smooth the actual attached shell, not a derivative of the underlying
		# height field: that derivative can point through a steep apron face.
		# Keep hard folds/caps in their outward hemisphere, as for earthworks.
		var sums:Dictionary={}
		for i in range(first_vertex,vertices.size()):sums[vertices[i]]=sums.get(vertices[i],Vector3.ZERO)+normals[i]
		for i in range(first_vertex,vertices.size()):
			var smooth:Vector3=sums[vertices[i]].normalized()
			if smooth.dot(normals[i])>.15:normals[i]=smooth
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=false
