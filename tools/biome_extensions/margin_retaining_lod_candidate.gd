extends "res://scripts/lod_biome_extension_structures.gd"
## Private, unregistered far-core LOD for hosts lacking an analytic height bound.
## ALL original apron/margin samples, cells and caps remain. Only the central
## upper surface simplifies; each proposed interval must retain upward winding.
var _allow_mixed_lod:bool=true
var retained_intervals:int=0
var fallback_intervals:int=0
func build(builder,coordinate:Vector2i,support_steps:PackedFloat64Array=PackedFloat64Array(),portal_provider:Callable=Callable())->Array:
	_allow_mixed_lod=builder.settings.alien_infected.hive_structure_lod_enabled
	return super.build(builder,coordinate,support_steps,portal_provider)
func select_stride(a:Vector2,b:Vector2,width:float,context:Dictionary)->int:
	if not _allow_mixed_lod or context.is_empty():return 1
	if is_finite(context.floor):return super.select_stride(a,b,width,context)
	var distance_context:Dictionary=context.duplicate();distance_context.floor=0.0
	return super.select_stride(a,b,width,distance_context)
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var context:Dictionary=builder.get_meta(CONTEXT,{})
	if not builder.settings.alien_infected.hive_structure_lod_enabled or not conduit_aprons:
		var previous:bool=_allow_mixed_lod;_allow_mixed_lod=false
		super._conduit_uncached(builder,a,b,width,phase,color);_allow_mixed_lod=previous;return
	_row_stride=select_stride(a,b,width,context)
	if _row_stride==1 or is_finite(context.get("floor",INF)):
		super._conduit_uncached(builder,a,b,width,phase,color);return
	_foundation_floor=INF
	emit_retained_margin_conduit(builder,a,b,width,phase,color)
	_row_stride=1
func proposed_triangle(a:Vector3,b:Vector3,c:Vector3)->PackedVector3Array:return PackedVector3Array([a,b,c])
func append_quad_faces(faces:Array[PackedVector3Array],a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	faces.append(proposed_triangle(a,b,c));faces.append(proposed_triangle(a,c,d))
func winding_valid(faces:Array[PackedVector3Array])->bool:
	for face:PackedVector3Array in faces:
		if (face[2]-face[0]).cross(face[1]-face[0]).y<=.00000001:return false
	return true
func core_proposal(rings:Array,low:int,high:int,left:int,right:int)->Array[PackedVector3Array]:
	var faces:Array[PackedVector3Array]=[]
	for column in range(left+1,right-1):append_quad_faces(faces,rings[low][column],rings[low][column+1],rings[high][column+1],rings[high][column])
	for row in range(low,high):
		faces.append(proposed_triangle(rings[row][left],rings[low][left+1],rings[row+1][left]))
		faces.append(proposed_triangle(rings[low][right-1],rings[row][right],rings[row+1][right]))
	faces.append(proposed_triangle(rings[high][left],rings[low][left+1],rings[high][left+1]))
	faces.append(proposed_triangle(rings[low][right-1],rings[high][right],rings[high][right-1]))
	return faces
func select_core_faces(rings:Array,low:int,high:int)->Array[PackedVector3Array]:
	var faces:Array[PackedVector3Array]=[]
	if high-low==1:
		# Exact original unit band, including its original diagonal choices.
		for column in range(3,11):append_quad_faces(faces,rings[low][column],rings[low][column+1],rings[high][column+1],rings[high][column])
		return faces
	var wide:Array[PackedVector3Array]=core_proposal(rings,low,high,3,11)
	if winding_valid(wide):return wide
	var middle:int=(low+high)/2
	faces=select_core_faces(rings,low,middle);faces.append_array(select_core_faces(rings,middle,high))
	# A narrow stitch can be cheaper than many original unit bands. Its outer
	# shoulder cells are still the exact original full-resolution triangles.
	var narrow:Array[PackedVector3Array]=core_proposal(rings,low,high,5,9)
	if winding_valid(narrow):
		for row in range(low,high):
			for column:int in [3,4,9,10]:append_quad_faces(narrow,rings[row][column],rings[row][column+1],rings[row+1][column+1],rings[row+1][column])
		if narrow.size()<faces.size():return narrow
	return faces
func triangulate_retained_margins(rings:Array,color:Color)->void:
	var segments:int=rings.size()-1;var selected:Array[int]=[]
	for row in range(0,segments,_row_stride):selected.append(row)
	selected.append(segments)
	for interval in range(selected.size()-1):
		var low:int=selected[interval];var high:int=selected[interval+1]
		# These are the exact original full-resolution apron AND shoulder cells.
		for row in range(low,high):
			for column:int in [0,1,2,11,12,13]:
				quad(rings[row][column],rings[row][column+1],rings[row+1][column+1],rings[row+1][column],color)
		var proposed:Array[PackedVector3Array]=select_core_faces(rings,low,high)
		if proposed.size()<16*(high-low):retained_intervals+=1
		else:fallback_intervals+=1
		for face:PackedVector3Array in proposed:triangle(face[0],face[1],face[2],color)
func emit_retained_margin_conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=conduit_aprons
	var first_vertex:int=vertices.size()
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var rings:Array=[]
	var segments:int=clampi(ceili(a.distance_to(b)/96),16,64)
	for row in range(segments+1):
		var t:float=float(row)/segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8
		var h:float=builder._get_height(p.x,p.y);var ring:=PackedVector3Array();var radius:float=width*(.7+.2*sin(t*9+phase)+.1*sin(t*23-phase))
		var row_controls:=Vector2.ZERO
		if conduit_aprons:
			builder._extras[7].sample(p.x,p.y)
			row_controls=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
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
				var foot:float=footing_height(builder,outer) if factor>0 else outer_ground-3
				var extra_depth:float=maxf(0,outer_ground-3-foot)
				var apron:=PackedVector3Array()
				for station in range(3):
					var u:float=float(3-station)/3
					var q:Vector2=p+side*sign_value*(radius+reach*factor*u)
					var y:float=builder._get_height(q.x,q.y)-3-extra_depth*smoothstep(.35,1,u)
					var v:=Vector3(q.x,y,q.y);apron.append(v)
					_footing_vertices[v-origin]=(0.0 if station==0 else .25) if factor>0 else .5
					builder._extras[7].sample(q.x,q.y)
					_conduit_uvs[v-origin]=Vector2(builder._extras[7].state[3]*5,builder._extras[7].state[4])
				if sign_value>0:
					profile.append_array(apron);profile.append_array(ring)
				else:
					apron.reverse();profile.append_array(apron)
			ring=profile
		rings.append(ring)
	triangulate_retained_margins(rings,color)
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

