extends "res://scripts/biome_extension_structures.gd"
## Private true-3D conduit LOD trial. No production registration.
## Exact original near geometry, unchanged world identities and complete landmarks.
const CONTEXT="private_far_conduit_lod_context"
var lod_enabled:bool=true
## Use the minimum supported split ratio, not an optimistic default distance.
var split_ratio:float=.5
var _row_stride:int=1
var _foundation_floor:float=INF
var conduit_ranges:Array[Vector2i]=[]
var detail_counts:Dictionary={}
func _init()->void:
	# Isolate geometry generation in this first private trial; production memo
	# integration needs detail-qualified keys before any adoption.
	conduit_cache_enabled=false
func supported_noise(n:FastNoiseLite)->bool:
	return n.noise_type==FastNoiseLite.TYPE_SIMPLEX_SMOOTH and n.fractal_type==FastNoiseLite.FRACTAL_FBM and not n.domain_warp_enabled and n.fractal_weighted_strength==0 and n.fractal_gain>=0
func global_floor(builder)->float:
	# FNL's configured OpenSimplex2S/FBM is bounded in [-1,1]. Use [-2,2]
	# conservatively, reject other algorithms/configurations rather than assume
	# the same for cellular noise. No bound is used for mixed/coastal worlds.
	# https://github.com/Auburn/FastNoiseLite/blob/master/Cpp/FastNoiseLite.h
	if builder.get_script()!=preload("res://scripts/terrain_mesh_builder.gd"):return INF
	if builder._extra_coverage[7]!=1 or builder._coast!=null:return INF
	var field=builder._extras[7];var config=field.settings
	if config.relief<0 or config.nerve_height<0 or config.overlay_strength<0:return INF
	for noise:FastNoiseLite in [field._macro,field._meso,builder._detail_noise]:
		if not supported_noise(noise):return INF
	# Nonnegative ridges/fibres/armor cannot lower this bound. Rupture country
	# subtracts at most breach_depth; regional interpolation is convex.
	var land_min:float=minf(60-2*280-2*5,60-2*100-2*4-maxf(config.breach_depth,0))*config.relief
	var ocean_min:float=-maxf(builder.settings.ocean_depth,1)-2*absf(builder.settings.seabed_relief)
	return builder.water_level+minf(land_min,ocean_min)*maxf(builder.settings.height_multiplier,.01)-32
func build(builder,coordinate:Vector2i,support_steps:PackedFloat64Array=PackedFloat64Array(),portal_provider:Callable=Callable())->Array:
	conduit_ranges.clear();detail_counts.clear()
	var had_context:bool=builder.has_meta(CONTEXT)
	var previous:Dictionary=builder.get_meta(CONTEXT,{})
	builder.set_meta(CONTEXT,{"bounds":Rect2(Vector2(coordinate)*builder.chunk_size,Vector2.ONE*builder.chunk_size),"ratio":split_ratio,"floor":global_floor(builder) if lod_enabled else INF})
	var output:Array=super.build(builder,coordinate,support_steps,portal_provider)
	if not had_context:builder.remove_meta(CONTEXT)
	else:builder.set_meta(CONTEXT,previous)
	return output
func select_stride(a:Vector2,b:Vector2,width:float,context:Dictionary)->int:
	if context.is_empty() or not is_finite(context.floor):return 1
	var leaf:Rect2=context.bounds;var radius:float=128+5.8*width
	var geometry:=Rect2(a,Vector2.ZERO).expand(b).grow(radius)
	var outside:float=0
	for q:Vector2 in [geometry.position,geometry.end,Vector2(geometry.position.x,geometry.end.y),Vector2(geometry.end.x,geometry.position.y)]:
		outside=maxf(outside,q.distance_to(q.clamp(leaf.position,leaf.end)))
	# Every retained production leaf is at least split_ratio*span from the
	# viewer. This bound includes ALL geometry extending beyond its owner.
	var viewer_clearance:float=leaf.size.x*context.ratio-outside
	return 4 if viewer_clearance>6000 else (2 if viewer_clearance>2000 else 1)
func _conduit_uncached(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	var begin:int=vertices.size()
	var context:Dictionary=builder.get_meta(CONTEXT,{})
	_row_stride=select_stride(a,b,width,context)
	detail_counts[_row_stride]=int(detail_counts.get(_row_stride,0))+1
	if _row_stride==1:
		super._conduit_uncached(builder,a,b,width,phase,color);conduit_ranges.append(Vector2i(begin,vertices.size()));return
	_foundation_floor=context.floor
	emit_far_conduit(builder,a,b,width,phase,color)
	conduit_ranges.append(Vector2i(begin,vertices.size()))
	_foundation_floor=INF;_row_stride=1
func footing_height(builder,p:Vector2)->float:
	return _foundation_floor if is_finite(_foundation_floor) else super.footing_height(builder,p)
func emit_far_conduit(builder,a:Vector2,b:Vector2,width:float,phase:float,color:Color)->void:
	_footing_vertices.clear();_conduit_uvs.clear();_skip_degenerate=conduit_aprons
	var first_vertex:int=vertices.size()
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x);var rings:Array=[]
	var original_segments:int=clampi(ceili(a.distance_to(b)/96),16,64)
	var selected_rows:Array[int]=[]
	for index in range(0,original_segments,_row_stride):selected_rows.append(index)
	selected_rows.append(original_segments)
	var segments:int=selected_rows.size()-1
	for row in range(segments+1):
		var t:float=float(selected_rows[row])/original_segments;var p:Vector2=a.lerp(b,t)+side*sin(t*PI)*width*.8
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
